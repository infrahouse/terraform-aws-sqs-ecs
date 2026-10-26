import json
import re
from os import path as osp, remove
from shutil import rmtree
from subprocess import PIPE, run
from textwrap import dedent
from typing import Any

import pytest
from pytest_infrahouse import terraform_apply

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
)

# The release a user upgrades from. Move it, and EXPECTED_CHANGES, with each
# release.
LATEST_RELEASE = "3.0.0"

# Every resource that planning this checkout over LATEST_RELEASE, with the same
# inputs, changes, and the attributes it changes. Each is an in-place update;
# anything else fails the test.
EXPECTED_CHANGES = {
    # The release's version in the queue's module_version tag. No redrive
    # policy: enable_dead_letter_queue is off by default.
    "module.test.aws_sqs_queue.queue": {"tags", "tags_all"},
    # instance-profile 2.0.0 (commit 120b30b, on main since 3.0.0) adds
    # ec2:DescribeTags and Amazon Inspector's CIS session actions to the
    # instance role's policy...
    "module.test.module.asg.module.instance-profile.aws_iam_policy.profile": {"policy"},
    # ...and moves its own module_version tag on the role.
    "module.test.module.asg.module.instance-profile.aws_iam_role.profile": {
        "tags",
        "tags_all",
    },
}


def _terraform(module_dir: str, *args: str) -> str:
    """
    Run a terraform command in a root module.

    :param module_dir: The root module's directory.
    :param args: The command and its arguments, after ``terraform``.
    :return: The command's stdout.
    :raise CalledProcessError: If terraform exits with non-zero.
    """
    LOG.info("Executing: terraform %s", " ".join(args))
    return run(
        ["terraform", *args], cwd=module_dir, stdout=PIPE, check=True, text=True
    ).stdout


def _has_unknown(value: Any) -> bool:
    """
    Tell whether a plan's ``after_unknown`` entry marks any value unknown.

    :param value: An entry of ``after_unknown``: a bool, or a list or dict of
        them, nested as the attribute is.
    :return: True if any value in it is unknown after the apply.
    """
    if isinstance(value, dict):
        return any(_has_unknown(item) for item in value.values())
    if isinstance(value, list):
        return any(_has_unknown(item) for item in value)
    return value is True


def _changed_attributes(change: dict) -> set[str]:
    """
    List the top-level attributes a planned change changes.

    :param change: A ``change`` object of the plan's ``resource_changes``.
    :return: Names of the attributes whose value differs after the apply, or
        that the plan only knows after the apply.
    """
    before = change["before"] or {}
    after = change["after"] or {}
    after_unknown = change.get("after_unknown") or {}
    return {
        name
        for name in before.keys() | after.keys() | after_unknown.keys()
        if before.get(name) != after.get(name) or _has_unknown(after_unknown.get(name))
    }


@pytest.mark.parametrize("aws_provider_version", ["~> 6.0"], ids=["aws-6"])
def test_upgrade_from_latest_release(
    service_network,
    test_role_arn,
    keep_after,
    aws_region,
    cleanup_ecs_task_definitions,
    aws_provider_version,
    tmp_path,
):
    """
    Applies LATEST_RELEASE from the registry, then plans this checkout over it
    with the same inputs, as a user's upgrade would.

    The plan must change exactly what EXPECTED_CHANGES lists: with the
    dead-letter queue off by default, nothing of it, and no redrive policy on
    the queue.
    """
    subnet_private_ids = service_network["subnet_private_ids"]["value"]

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "sqs-ecs-upgrade")

    # Clean Terraform state to force re-init with the specified provider version
    for state_path in [
        osp.join(terraform_module_dir, ".terraform"),
        osp.join(terraform_module_dir, ".terraform.lock.hcl"),
    ]:
        try:
            if osp.isdir(state_path):
                rmtree(state_path)
            elif osp.isfile(state_path):
                remove(state_path)
        except FileNotFoundError:
            pass

    # Generate terraform.tf with the parametrized provider version
    with open(osp.join(terraform_module_dir, "terraform.tf"), "w") as fp:
        fp.write(dedent(f"""\
                terraform {{
                  required_version = "~> 1.5"
                  //noinspection HILUnresolvedReference
                  required_providers {{
                    aws = {{
                      source  = "hashicorp/aws"
                      version = "{aws_provider_version}"
                    }}
                    random = {{
                      source  = "hashicorp/random"
                      version = "~> 3.6"
                    }}
                  }}
                }}
                """))

    with open(osp.join(terraform_module_dir, "terraform.tfvars"), "w") as fp:
        fp.write(dedent(f"""
                    region                     = "{aws_region}"
                    consumer_subnet_ids        = {json.dumps(subnet_private_ids)}
                    """))
        if test_role_arn:
            fp.write(dedent(f"""
                    role_arn        = "{test_role_arn}"
                    """))

    # main.tf as committed calls the module in this checkout; the release's
    # main.tf calls LATEST_RELEASE from the registry instead.
    main_tf_path = osp.join(terraform_module_dir, "main.tf")
    with open(main_tf_path) as fp:
        checkout_main_tf = fp.read()
    release_main_tf, sources = re.subn(
        r'^([ \t]*)source\s*=\s*"\./\.\./\.\./"$',
        rf'\1source  = "registry.infrahouse.com/infrahouse/sqs-ecs/aws"\n'
        rf'\1version = "{LATEST_RELEASE}"',
        checkout_main_tf,
        flags=re.MULTILINE,
    )
    assert sources == 1, f"Expected one local module source in {main_tf_path}"

    plan_path = str(tmp_path / "upgrade.plan")
    try:
        with open(main_tf_path, "w") as fp:
            fp.write(release_main_tf)

        with terraform_apply(
            terraform_module_dir,
            destroy_after=not keep_after,
            json_output=True,
        ) as tf_output:
            LOG.info("%s", json.dumps(tf_output, indent=4))
            cleanup_ecs_task_definitions(tf_output["service_name"]["value"])

            # The upgrade: the same inputs, this checkout's module. The destroy
            # after the test runs with it too.
            with open(main_tf_path, "w") as fp:
                fp.write(checkout_main_tf)
            _terraform(terraform_module_dir, "init", "-input=false", "-no-color")
            _terraform(
                terraform_module_dir,
                "plan",
                "-var-file=terraform.tfvars",
                "-input=false",
                "-no-color",
                f"-out={plan_path}",
            )
            plan = json.loads(
                _terraform(terraform_module_dir, "show", "-json", plan_path)
            )

            changes = {
                resource_change["address"]: resource_change["change"]
                for resource_change in plan.get("resource_changes", [])
                if resource_change["mode"] == "managed"
                and resource_change["change"]["actions"] != ["no-op"]
            }
            changed_attributes = {
                address: _changed_attributes(change)
                for address, change in changes.items()
            }
            LOG.info(
                "Upgrade from %s changes: %s",
                LATEST_RELEASE,
                json.dumps(
                    {
                        address: {
                            "actions": change["actions"],
                            "attributes": sorted(changed_attributes[address]),
                        }
                        for address, change in changes.items()
                    },
                    indent=4,
                ),
            )
            assert {
                address: change["actions"] for address, change in changes.items()
            } == {address: ["update"] for address in EXPECTED_CHANGES}
            assert changed_attributes == EXPECTED_CHANGES
    finally:
        with open(main_tf_path, "w") as fp:
            fp.write(checkout_main_tf)
