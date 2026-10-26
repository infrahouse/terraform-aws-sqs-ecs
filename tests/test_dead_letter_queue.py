import json
from os import path as osp, remove
from secrets import token_hex
from shutil import rmtree
from textwrap import dedent
from time import time
from typing import Any
from uuid import uuid4

import pytest
from pytest_infrahouse import terraform_apply

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
)

# The module's default dead_letter_queue_max_receive_count. The test root
# doesn't pass the variable, so the redrive below runs with the default.
DEFAULT_MAX_RECEIVE_COUNT = 5

# SQS's maximum retention, which the module gives the dead-letter queue.
DEAD_LETTER_QUEUE_RETENTION_SECONDS = 14 * 24 * 3600


def _receive(sqs: Any, queue_url: str) -> list[dict]:
    """
    Long-poll a queue for one message and leave it visible.

    :param sqs: A boto3 SQS client.
    :param queue_url: URL of the queue to receive from.
    :return: The received messages: one, or none if the queue had nothing.
    """
    return sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1,
        # Long polling asks every SQS server, so an empty answer means the
        # queue has no visible message, not that a sample of servers had none.
        WaitTimeSeconds=20,
        # Visible again at once, so the next receive gets the message back
        # without waiting out a visibility timeout.
        VisibilityTimeout=0,
        MessageSystemAttributeNames=["ApproximateReceiveCount"],
    ).get("Messages", [])


@pytest.mark.parametrize("aws_provider_version", ["~> 6.0"], ids=["aws-6"])
@pytest.mark.parametrize("fifo_queue", [False, True], ids=["standard", "fifo"])
def test_dead_letter_queue(
    service_network,
    test_role_arn,
    keep_after,
    aws_region,
    boto3_session,
    cleanup_ecs_task_definitions,
    aws_provider_version,
    fifo_queue,
):
    """
    Deploys the module with ``enable_dead_letter_queue = true`` and drives a
    message into the dead-letter queue.

    - ``standard``: AWS names the queue; the dead-letter queue is named after
      it, with ``-dlq``.
    - ``fifo``: a FIFO queue the caller names gets a FIFO dead-letter queue,
      ``<name>-dlq.fifo``.

    A message received ``DEFAULT_MAX_RECEIVE_COUNT`` times without being
    deleted must leave the queue on the next receive and land in the
    dead-letter queue, and the depth alarm must watch the dead-letter queue
    through the module's SNS topic.
    """
    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    queue_name = f"sqs-dlq-test-{token_hex(3)}.fifo" if fifo_queue else None

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
                    region                   = "{aws_region}"
                    consumer_subnet_ids      = {json.dumps(subnet_private_ids)}
                    fifo_queue               = {str(fifo_queue).lower()}
                    enable_dead_letter_queue = true
                    """))
        if queue_name:
            fp.write(f'queue_name = "{queue_name}"\n')
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

        sqs = boto3_session.client("sqs", region_name=aws_region)
        cloudwatch = boto3_session.client("cloudwatch", region_name=aws_region)

        main_name = tf_output["queue_name"]["value"]
        main_url = tf_output["queue_url"]["value"]
        main_arn = tf_output["queue_arn"]["value"]
        dlq_name = tf_output["dead_letter_queue_name"]["value"]
        dlq_url = tf_output["dead_letter_queue_url"]["value"]
        dlq_arn = tf_output["dead_letter_queue_arn"]["value"]

        if fifo_queue:
            assert main_name == queue_name
            assert dlq_name == f"{queue_name.removesuffix('.fifo')}-dlq.fifo"
        else:
            assert dlq_name == f"{main_name}-dlq"

        # The redrive: the queue names the dead-letter queue, and the
        # dead-letter queue admits only this queue.
        main_attributes = sqs.get_queue_attributes(
            QueueUrl=main_url, AttributeNames=["All"]
        )["Attributes"]
        dlq_attributes = sqs.get_queue_attributes(
            QueueUrl=dlq_url, AttributeNames=["All"]
        )["Attributes"]
        LOG.info("Queue attributes: %s", json.dumps(main_attributes, indent=4))
        LOG.info(
            "Dead-letter queue attributes: %s", json.dumps(dlq_attributes, indent=4)
        )

        redrive_policy = json.loads(main_attributes["RedrivePolicy"])
        assert redrive_policy["deadLetterTargetArn"] == dlq_arn
        assert int(redrive_policy["maxReceiveCount"]) == DEFAULT_MAX_RECEIVE_COUNT
        assert json.loads(dlq_attributes["RedriveAllowPolicy"]) == {
            "redrivePermission": "byQueue",
            "sourceQueueArns": [main_arn],
        }
        assert "RedrivePolicy" not in dlq_attributes

        # Encrypted as the queue is, FIFO when the queue is, and kept 14 days.
        assert main_attributes["SqsManagedSseEnabled"] == "true"
        assert dlq_attributes["SqsManagedSseEnabled"] == "true"
        expected_fifo = "true" if fifo_queue else "false"
        assert main_attributes.get("FifoQueue", "false") == expected_fifo
        assert dlq_attributes.get("FifoQueue", "false") == expected_fifo
        assert int(dlq_attributes["MessageRetentionPeriod"]) == (
            DEAD_LETTER_QUEUE_RETENTION_SECONDS
        )

        # A message nobody deletes: received DEFAULT_MAX_RECEIVE_COUNT times,
        # then moved to the dead-letter queue by the receive after that.
        body = json.dumps({"test": "test_dead_letter_queue", "id": str(uuid4())})
        send_options = (
            {"MessageGroupId": "pytest", "MessageDeduplicationId": str(uuid4())}
            if fifo_queue
            else {}
        )
        sqs.send_message(QueueUrl=main_url, MessageBody=body, **send_options)

        receive_counts = []
        # One receive more than the limit: that one must come back empty.
        for _ in range(DEFAULT_MAX_RECEIVE_COUNT + 1):
            messages = _receive(sqs, main_url)
            if not messages:
                break
            assert messages[0]["Body"] == body
            receive_counts.append(messages[0]["Attributes"]["ApproximateReceiveCount"])
        LOG.info("ApproximateReceiveCount of each receive: %s", receive_counts)
        assert len(receive_counts) == DEFAULT_MAX_RECEIVE_COUNT

        dead_letters = []
        deadline = time() + 120
        while not dead_letters and time() < deadline:
            dead_letters = _receive(sqs, dlq_url)
        assert [message["Body"] for message in dead_letters] == [body]

        # The depth alarm: any message in the dead-letter queue, emailed through
        # the topic the message-age alarm uses.
        alarms = cloudwatch.describe_alarms(AlarmNames=[f"{dlq_name}-depth-alarm"])[
            "MetricAlarms"
        ]
        assert len(alarms) == 1
        alarm = alarms[0]
        assert alarm["Namespace"] == "AWS/SQS"
        assert alarm["MetricName"] == "ApproximateNumberOfMessagesVisible"
        assert alarm["Dimensions"] == [{"Name": "QueueName", "Value": dlq_name}]
        assert alarm["Statistic"] == "Maximum"
        assert alarm["ComparisonOperator"] == "GreaterThanThreshold"
        assert alarm["Threshold"] == 0
        assert alarm["TreatMissingData"] == "notBreaching"

        age_alarm = cloudwatch.describe_alarms(
            AlarmNames=[f"{main_name}-message-age-alarm"]
        )["MetricAlarms"][0]
        assert alarm["AlarmActions"] == age_alarm["AlarmActions"]
        assert alarm["OKActions"] == age_alarm["OKActions"]
