import json
import time
from os import path as osp, remove
from shutil import rmtree
from textwrap import dedent

import pytest
from infrahouse_core.aws import ECRRepository
from infrahouse_core.timeout import timeout
from pytest_infrahouse import terraform_apply

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
)


def _wait_until_stable(
    ecs_client, cluster: str, service: str, max_wait: int = 600
) -> None:
    """Poll an ECS service until it is stable, logging progress each poll.

    boto3's ``services_stable`` waiter polls silently, so a service that is
    failing to start tasks looks identical to one that is simply slow. This
    helper logs the running/desired/pending counts and rollout state on every
    poll and fails fast when the rollout state is ``FAILED`` instead of waiting
    out the whole timeout.

    :param ecs_client: A boto3 ECS client.
    :param cluster: ECS cluster name.
    :param service: ECS service name.
    :param max_wait: Maximum seconds to wait for the service to stabilize.
    :raises TimeoutError: If the service does not stabilize within ``max_wait``.
    :raises RuntimeError: If the deployment rollout state becomes ``FAILED``.
    """
    with timeout(max_wait):
        while True:
            service_description = ecs_client.describe_services(
                cluster=cluster, services=[service]
            )["services"][0]
            deployments = service_description["deployments"]
            primary = next(
                (d for d in deployments if d["status"] == "PRIMARY"),
                deployments[0],
            )
            rollout_state = primary.get("rolloutState")
            LOG.info(
                "Service %s: desired=%d running=%d pending=%d rollout=%s deployments=%d",
                service,
                service_description["desiredCount"],
                service_description["runningCount"],
                service_description["pendingCount"],
                rollout_state,
                len(deployments),
            )
            if rollout_state == "FAILED":
                recent_events = [
                    e["message"] for e in service_description["events"][:5]
                ]
                raise RuntimeError(
                    f"Deployment for {service} failed. Recent events: {recent_events}"
                )
            if (
                len(deployments) == 1
                and service_description["runningCount"]
                == service_description["desiredCount"]
            ):
                LOG.info("Service %s is stable.", service)
                return
            time.sleep(15)


@pytest.mark.parametrize("aws_provider_version", ["~> 6.0"], ids=["aws-6"])
def test_ecr_image_tagging(
    service_network,
    test_role_arn,
    keep_after,
    aws_region,
    cleanup_ecs_task_definitions,
    aws_provider_version,
    boto3_session,
):
    """
    Proves the ECR image tagger Lambda tags the deployed image.

    Pushes an image into a fresh ECR repository, deploys the module with
    ``enable_ecr_image_tagging = true``, forces a new ECS deployment so
    EventBridge fires ``SERVICE_STEADY_STATE`` after the rule and Lambda
    exist, then polls ECR until the ``deployed-at-*`` tag appears.
    """
    subnet_private_ids = service_network["subnet_private_ids"]["value"]

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "sqs-ecs-ecr-tagger")

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
                    null = {{
                      source  = "hashicorp/null"
                      version = "~> 3.0"
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
                    role_arn = "{test_role_arn}"
                    """))

    with terraform_apply(
        terraform_module_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        LOG.info("%s", json.dumps(tf_output, indent=4))

        cluster_name = tf_output["cluster_name"]["value"]
        service_name = tf_output["service_name"]["value"]
        ecr_repo_name = tf_output["ecr_repo_name"]["value"]
        cleanup_ecs_task_definitions(service_name)

        ecs_client = boto3_session.client("ecs", region_name=aws_region)

        # Wait for the initial deployment to reach steady state.
        LOG.info("Waiting for the consumer service to stabilize...")
        _wait_until_stable(ecs_client, cluster_name, service_name)

        # Force a new deployment so EventBridge fires SERVICE_STEADY_STATE
        # *after* the rule and Lambda exist. The initial steady state event
        # likely fired during terraform apply before the rule was created.
        LOG.info("Forcing new ECS deployment to trigger SERVICE_STEADY_STATE...")
        ecs_client.update_service(
            cluster=cluster_name,
            service=service_name,
            forceNewDeployment=True,
        )
        _wait_until_stable(ecs_client, cluster_name, service_name)
        LOG.info("Service is stable after forced deployment.")

        # Poll ECR for the deployed-at- tag. EventBridge -> Lambda is async,
        # so the tag may take up to a minute to appear.
        LOG.info("Checking ECR repo %s for a deployed-at- tag...", ecr_repo_name)
        repo = ECRRepository(
            ecr_repo_name,
            session=boto3_session,
            region=aws_region,
        )
        assert repo.exists, f"ECR repository {ecr_repo_name} does not exist"

        image = repo.get_image(tag="latest")
        assert image.exists, "Image 'latest' does not exist in the ECR repo"

        deployed_tag = None
        try:
            with timeout(300):
                while deployed_tag is None:
                    tags = image.tags
                    LOG.info("Current image tags: %s", tags)
                    for tag in tags:
                        if tag.startswith("deployed-at-"):
                            deployed_tag = tag
                            break
                    if deployed_tag is None:
                        LOG.info("No deployed-at- tag yet, retrying in 10s...")
                        time.sleep(10)
        except TimeoutError:
            pytest.fail(
                "ECR image was not tagged with deployed-at-* "
                "within 5 minutes of steady state"
            )

        LOG.info("ECR image tagged successfully: %s", deployed_tag)
