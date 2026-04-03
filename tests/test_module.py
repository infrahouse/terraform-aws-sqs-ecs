import json
from os import path as osp, remove
from shutil import rmtree
from textwrap import dedent

import pytest
from pytest_infrahouse import terraform_apply

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
)


@pytest.mark.parametrize(
    "aws_provider_version", ["~> 5.62", "~> 6.0"], ids=["aws-5", "aws-6"]
)
def test_module(
    service_network,
    test_role_arn,
    keep_after,
    aws_region,
    cleanup_ecs_task_definitions,
    aws_provider_version,
):
    subnet_private_ids = service_network["subnet_private_ids"]["value"]

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "sql-ecs")

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
                    region              = "{aws_region}"
                    consumer_subnet_ids = {json.dumps(subnet_private_ids)}
                    """))
        if test_role_arn:
            fp.write(dedent(f"""
                    role_arn        = "{test_role_arn}"
                    """))

    with terraform_apply(
        terraform_module_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        LOG.info("%s", json.dumps(tf_output, indent=4))
        cleanup_ecs_task_definitions(tf_output["service_name"]["value"])
