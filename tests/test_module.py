import json
from os import path as osp, remove
from shutil import rmtree
from textwrap import dedent
from time import sleep, time
from typing import Any, Callable, TypeVar
from uuid import uuid4

import boto3
import pytest
from infrahouse_core.aws.ec2_instance import EC2Instance
from pytest_infrahouse import terraform_apply

from tests.conftest import (
    AL2023_ECS_IMAGES,
    AMAZON,
    LOG,
    TERRAFORM_ROOT_DIR,
)

# How long the instance, the agents and the consumer may take after the apply.
READY_TIMEOUT = 15 * 60

T = TypeVar("T")


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


def _wait_for(check: Callable[[], T], what: str, timeout: int = READY_TIMEOUT) -> T:
    """
    Call a check every 15 seconds until it returns something truthy.

    :param check: Returns what the test waits for, or something falsy.
    :param what: What the test waits for, for the log and the failure.
    :param timeout: Seconds to wait at most.
    :return: The check's first truthy result.
    :raise AssertionError: If the time runs out first.
    """
    deadline = time() + timeout
    while True:
        result = check()
        if result:
            return result
        assert time() < deadline, f"Gave up waiting for {what} after {timeout} s"
        LOG.info("Waiting for %s", what)
        sleep(15)


def _connected_instances(ecs: Any, cluster: str) -> list[str]:
    """
    List the EC2 instances whose ECS agent is connected to a cluster.

    :param ecs: A boto3 ECS client.
    :param cluster: The cluster's name.
    :return: Instance ids of the cluster's active, connected container
        instances.
    """
    arns = ecs.list_container_instances(cluster=cluster, status="ACTIVE")[
        "containerInstanceArns"
    ]
    if not arns:
        return []
    return [
        instance["ec2InstanceId"]
        for instance in ecs.describe_container_instances(
            cluster=cluster, containerInstances=arns
        )["containerInstances"]
        if instance["agentConnected"]
    ]


def _running_tasks(ecs: Any, cluster: str, service: str) -> list[str]:
    """
    List a service's tasks that are running.

    :param ecs: A boto3 ECS client.
    :param cluster: The cluster's name.
    :param service: The service's name.
    :return: ARNs of the service's tasks whose last status is RUNNING.
    """
    arns = ecs.list_tasks(cluster=cluster, serviceName=service)["taskArns"]
    if not arns:
        return []
    return [
        task["taskArn"]
        for task in ecs.describe_tasks(cluster=cluster, tasks=arns)["tasks"]
        if task["lastStatus"] == "RUNNING"
    ]


def _default_image(ec2: Any, launched_at: Any) -> dict:
    """
    Find the image the module's default picks: the newest Amazon Linux 2023
    ECS-optimized x86_64 image, as of an instance's launch.

    :param ec2: A boto3 EC2 client.
    :param launched_at: The instance's launch time. An image published after
        it can't be the instance's.
    :return: The image, as DescribeImages answers it.
    """
    images = ec2.describe_images(
        Owners=[AMAZON],
        Filters=[
            {"Name": "name", "Values": [AL2023_ECS_IMAGES]},
            {"Name": "architecture", "Values": ["x86_64"]},
            {"Name": "virtualization-type", "Values": ["hvm"]},
        ],
    )["Images"]
    launched = launched_at.strftime("%Y-%m-%dT%H:%M:%S")
    return max(
        (image for image in images if image["CreationDate"][:19] <= launched),
        key=lambda image: image["CreationDate"],
    )


def _run(instance: EC2Instance, command: str) -> str:
    """
    Run a shell command on an instance through SSM.

    :param instance: The instance.
    :param command: The command.
    :return: Its stdout, stripped.
    :raise AssertionError: If it exits with non-zero.
    """
    exit_code, stdout, stderr = instance.execute_command(command)
    LOG.info("%s: exit %s, stdout %r, stderr %r", command, exit_code, stdout, stderr)
    assert exit_code == 0, f"{command}: exit {exit_code}: {stderr}"
    return stdout.strip()


def _log_events(logs: Any, group: str, pattern: str | None = None) -> list[dict]:
    """
    Read a log group's events, every page: FilterLogEvents may answer an empty
    page with a token for the next.

    :param logs: A boto3 CloudWatch Logs client.
    :param group: The log group's name.
    :param pattern: A filter pattern, or None for every event.
    :return: The events.
    """
    arguments = {"logGroupName": group}
    if pattern:
        arguments["filterPattern"] = pattern
    return [
        event
        for page in logs.get_paginator("filter_log_events").paginate(**arguments)
        for event in page["events"]
    ]


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

    Both run the default image, Amazon Linux 2023, and the test consumer
    (``test_data/sql-ecs/files/consumer.py``): the instance registers with the
    cluster, the consumer consumes a message, everything the module's
    cloud-init writes and runs works on the host, and the CloudWatch agent
    ships the host's syslog and dmesg.
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
                    run_test_consumer          = true
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

        _check_the_host(
            boto3_session,
            aws_region,
            tf_output,
            enable_cloudwatch_logs,
            enable_vector_agent,
        )


def _check_the_host(
    boto3_session: Any,
    aws_region: str,
    tf_output: dict,
    enable_cloudwatch_logs: bool,
    enable_vector_agent: bool,
) -> None:
    """
    Check the consumer's instance and what runs on it.

    :param boto3_session: A session with the test role.
    :param aws_region: The test's Region.
    :param tf_output: The test root's outputs.
    :param enable_cloudwatch_logs: The module's enable_cloudwatch_logs.
    :param enable_vector_agent: The module's enable_vector_agent.
    """
    service_name = tf_output["service_name"]["value"]
    ecs = boto3_session.client("ecs", region_name=aws_region)
    ec2 = boto3_session.client("ec2", region_name=aws_region)
    sqs = boto3_session.client("sqs", region_name=aws_region)
    logs = boto3_session.client("logs", region_name=aws_region)

    # The instance registers with the cluster: cloud-init wrote ECS_CLUSTER.
    instance_ids = _wait_for(
        lambda: _connected_instances(ecs, service_name),
        "an instance connected to the cluster",
    )
    assert len(instance_ids) == 1, instance_ids
    instance_id = instance_ids[0]

    # It runs the default image: Amazon Linux 2023, ECS-optimized.
    described = ec2.describe_instances(InstanceIds=[instance_id])
    instance = described["Reservations"][0]["Instances"][0]
    image = ec2.describe_images(ImageIds=[instance["ImageId"]])["Images"][0]
    LOG.info("The instance runs %s (%s)", image["Name"], image["ImageId"])
    assert image["ImageId"] == _default_image(ec2, instance["LaunchTime"])["ImageId"]
    assert image["Name"].startswith("al2023-ami-ecs-hvm-")
    assert image["OwnerId"] == AMAZON

    # One hop to the instance metadata, as on Amazon Linux 2: a task's
    # container doesn't reach the instance role's credentials.
    assert instance["MetadataOptions"]["HttpTokens"] == "required"
    assert instance["MetadataOptions"]["HttpPutResponseHopLimit"] == 1

    # Its root device is the image's: the launch template sized and encrypted
    # it, rather than adding a volume.
    volumes = {
        mapping["DeviceName"]: mapping["Ebs"]["VolumeId"]
        for mapping in instance["BlockDeviceMappings"]
    }
    assert list(volumes) == [image["RootDeviceName"]], volumes
    root_volume = ec2.describe_volumes(VolumeIds=list(volumes.values()))["Volumes"][0]
    assert root_volume["Encrypted"]
    assert root_volume["Size"] == 30

    # The consumer consumes a message: it prints the body and deletes it.
    body = json.dumps({"test": "test_module", "id": str(uuid4())})
    sqs.send_message(QueueUrl=tf_output["queue_url"]["value"], MessageBody=body)
    consumed = _wait_for(
        lambda: _log_events(
            logs,
            f"/ecs/development/{service_name}",
            f'"{json.loads(body)["id"]}"',
        ),
        "the consumer to consume the message",
    )
    assert [event["message"] for event in consumed] == [f"Consumed: {body}"]
    _wait_for(
        lambda: all(
            count == "0"
            for count in sqs.get_queue_attributes(
                QueueUrl=tf_output["queue_url"]["value"],
                AttributeNames=[
                    "ApproximateNumberOfMessages",
                    "ApproximateNumberOfMessagesNotVisible",
                ],
            )["Attributes"].values()
        ),
        "the queue to be empty",
        timeout=120,
    )

    # What cloud-init writes and runs, on the host.
    host = EC2Instance(instance_id, region=aws_region, session=boto3_session)
    assert _run(host, "cloud-init status") == "status: done"
    memory_mib = ec2.describe_instance_types(InstanceTypes=[instance["InstanceType"]])[
        "InstanceTypes"
    ][0]["MemoryInfo"]["SizeInMiB"]
    # Twice the instance's memory. swapon reports the swap area, a page less.
    assert _run(host, "swapon --show=NAME --noheadings") == "/swapfile"
    assert _run(host, "stat -c %s /swapfile") == str(memory_mib * 2 * 1024 * 1024)
    assert f"ECS_CLUSTER={service_name}" in _run(host, "cat /etc/ecs/ecs.config")
    # cgroup v2: page cache counts toward a container's memory (README.md).
    assert _run(host, "stat -fc %T /sys/fs/cgroup") == "cgroup2fs"

    if enable_cloudwatch_logs:
        # The files the CloudWatch agent tails, and the agent shipping them.
        assert _run(host, "systemctl is-active rsyslog") == "active"
        _run(host, "test -s /var/log/messages && test -s /var/log/dmesg")
        for group in ["syslog", "dmesg"]:
            _wait_for(
                lambda: _log_events(logs, f"/ecs/development/{service_name}-{group}"),
                f"the host's {group} in CloudWatch",
            )

    if enable_vector_agent:
        # Vector's config is on the host, and its daemon runs.
        _run(host, "test -s /etc/vector/vector.yaml")
        _wait_for(
            lambda: _running_tasks(ecs, service_name, "vector-agent-daemon"),
            "Vector's daemon to run",
        )
