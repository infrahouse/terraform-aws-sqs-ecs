import json
from os import path as osp, remove
from shutil import rmtree
from textwrap import dedent
from typing import Any

import boto3
import pytest
from pytest_infrahouse import terraform_apply

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
)


def _ecs_client(aws_region: str, test_role_arn: str | None) -> Any:
    session = boto3.Session(region_name=aws_region)
    if not test_role_arn:
        return session.client("ecs")

    credentials = session.client("sts").assume_role(
        RoleArn=test_role_arn,
        RoleSessionName="sqs-ecs-test-inspect",
    )["Credentials"]
    return boto3.client(
        "ecs",
        region_name=aws_region,
        aws_access_key_id=credentials["AccessKeyId"],
        aws_secret_access_key=credentials["SecretAccessKey"],
        aws_session_token=credentials["SessionToken"],
    )


@pytest.mark.parametrize("aws_provider_version", ["~> 6.0"], ids=["aws-6"])
@pytest.mark.parametrize(
    "daemon_mode",
    [
        # (enable_cloudwatch_logs, enable_vector_agent)
        (True, False),
        (True, True),
    ],
    ids=["cw-only", "cw-and-vector"],
)
def test_module(
    service_network,
    test_role_arn,
    keep_after,
    aws_region,
    boto3_session,
    cleanup_ecs_task_definitions,
    aws_provider_version,
    daemon_mode,
):
    """
    Deploys the module against a real VPC and exercises the daemon flags.

    - ``cw-only``: defaults (CloudWatch agent on, Vector off). Baseline.
    - ``cw-and-vector``: Vector agent on alongside CloudWatch. A dummy
      aggregator endpoint is supplied; the daemon container will fail to
      connect, but the Terraform apply still succeeds, which is what this
      test validates.

    Both leave ``enable_dead_letter_queue`` off, its default: no dead-letter
    queue, no redrive policy on the queue and no depth alarm.
    """
    enable_cloudwatch_logs, enable_vector_agent = daemon_mode
    expected_memory_reservation = None if enable_vector_agent else 128
    expected_memory = 128 if expected_memory_reservation is None else 256
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
                    region                     = "{aws_region}"
                    consumer_subnet_ids        = {json.dumps(subnet_private_ids)}
                    enable_cloudwatch_logs     = {str(enable_cloudwatch_logs).lower()}
                    enable_vector_agent        = {str(enable_vector_agent).lower()}
                    """))
        if expected_memory != 128:
            fp.write(f"consumer_task_quota_memory = {expected_memory}\n")
        if expected_memory_reservation is not None:
            fp.write(
                f"consumer_task_quota_memory_reservation = {expected_memory_reservation}\n"
            )
        if enable_vector_agent:
            # Dummy endpoint — satisfies the precondition; runtime connect will fail harmlessly.
            fp.write('vector_aggregator_endpoint = "vector-aggregator.invalid:6000"\n')
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
        ecs = _ecs_client(aws_region, test_role_arn)
        task_definition = ecs.describe_task_definition(
            taskDefinition=tf_output["task_definition_arn"]["value"],
        )["taskDefinition"]
        container_definition = next(
            container
            for container in task_definition["containerDefinitions"]
            if container["name"] == tf_output["service_name"]["value"]
        )
        assert container_definition["memory"] == expected_memory
        if expected_memory_reservation is None:
            assert "memoryReservation" not in container_definition
        else:
            assert (
                container_definition["memoryReservation"] == expected_memory_reservation
            )
        cleanup_ecs_task_definitions(tf_output["service_name"]["value"])

        # Without the dead-letter queue. Terraform leaves a root output whose
        # value is null out of `terraform output`, hence get().
        for output in [
            "dead_letter_queue_name",
            "dead_letter_queue_url",
            "dead_letter_queue_arn",
        ]:
            assert tf_output.get(output, {}).get("value") is None, output

        sqs = boto3_session.client("sqs", region_name=aws_region)
        queue_attributes = sqs.get_queue_attributes(
            QueueUrl=tf_output["queue_url"]["value"], AttributeNames=["All"]
        )["Attributes"]
        assert "RedrivePolicy" not in queue_attributes

        # The message-age alarm is the queue's only alarm.
        queue_name = tf_output["queue_name"]["value"]
        cloudwatch = boto3_session.client("cloudwatch", region_name=aws_region)
        alarms = cloudwatch.describe_alarms(AlarmNamePrefix=queue_name)["MetricAlarms"]
        assert [alarm["AlarmName"] for alarm in alarms] == [
            f"{queue_name}-message-age-alarm"
        ]
