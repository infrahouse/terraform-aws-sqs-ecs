"""
The test consumer: receives the module's queue's messages, prints each body
and deletes the message, as a consumer of the module would.

Standard library only, so the stock Python image runs it as it is. It reads the
queue's URL and Region from the variables the module gives every consumer
(``SQS_ECS_QUEUE_URL``, ``AWS_DEFAULT_REGION``), and the task role's credentials
from the ECS credentials endpoint, and signs its SQS requests (Signature
Version 4, the JSON protocol) itself.

tests/test_module.py sends a message and looks for its body in the consumer's
log.
"""

import hashlib
import hmac
import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone

CREDENTIALS_ENDPOINT = "http://169.254.170.2"
SERVICE = "sqs"


def credentials() -> dict:
    """
    Read the task role's credentials from the ECS credentials endpoint.

    :return: The endpoint's answer: ``AccessKeyId``, ``SecretAccessKey``,
        ``Token`` and ``Expiration``.
    """
    url = CREDENTIALS_ENDPOINT + os.environ["AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"]
    with urllib.request.urlopen(url, timeout=5) as response:
        return json.load(response)


def signed_headers(
    host: str, region: str, target: str, body: bytes, keys: dict, now: datetime
) -> dict:
    """
    Make the headers of a signed SQS JSON-protocol request.

    :param host: The SQS endpoint's host name.
    :param region: The queue's Region.
    :param target: The SQS action, such as ``ReceiveMessage``.
    :param body: The request's JSON body.
    :param keys: Credentials: ``AccessKeyId``, ``SecretAccessKey`` and
        ``Token``.
    :param now: The time to sign the request at.
    :return: The request's headers, ``Authorization`` among them.
    """
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    day = now.strftime("%Y%m%d")
    headers = {
        "content-type": "application/x-amz-json-1.0",
        "host": host,
        "x-amz-date": amz_date,
        "x-amz-security-token": keys["Token"],
        "x-amz-target": f"AmazonSQS.{target}",
    }
    names = sorted(headers)
    signed_names = ";".join(names)
    canonical_request = "\n".join(
        [
            "POST",
            "/",
            "",
            "".join(f"{name}:{headers[name]}\n" for name in names),
            signed_names,
            hashlib.sha256(body).hexdigest(),
        ]
    )
    scope = f"{day}/{region}/{SERVICE}/aws4_request"
    string_to_sign = "\n".join(
        [
            "AWS4-HMAC-SHA256",
            amz_date,
            scope,
            hashlib.sha256(canonical_request.encode()).hexdigest(),
        ]
    )
    key = ("AWS4" + keys["SecretAccessKey"]).encode()
    for part in (day, region, SERVICE, "aws4_request"):
        key = hmac.new(key, part.encode(), hashlib.sha256).digest()
    signature = hmac.new(key, string_to_sign.encode(), hashlib.sha256).hexdigest()
    headers["authorization"] = (
        f"AWS4-HMAC-SHA256 Credential={keys['AccessKeyId']}/{scope}, "
        f"SignedHeaders={signed_names}, Signature={signature}"
    )
    return headers


def call(region: str, target: str, payload: dict) -> dict:
    """
    Call an SQS action with the task role's credentials.

    :param region: The queue's Region.
    :param target: The SQS action, such as ``ReceiveMessage``.
    :param payload: The action's parameters.
    :return: SQS's answer.
    :raise urllib.error.HTTPError: If SQS refuses the request; its body is
        printed first.
    """
    host = f"sqs.{region}.amazonaws.com"
    body = json.dumps(payload).encode()
    headers = signed_headers(
        host, region, target, body, credentials(), datetime.now(timezone.utc)
    )
    request = urllib.request.Request(
        f"https://{host}/", data=body, headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        print(f"{target} refused: {error.code} {error.read().decode()}", flush=True)
        raise


def main() -> None:
    """
    Receive, print and delete the queue's messages, one at a time, forever.
    """
    region = os.environ["AWS_DEFAULT_REGION"]
    queue_url = os.environ["SQS_ECS_QUEUE_URL"]
    print(f"Consuming {queue_url}", flush=True)
    while True:
        answer = call(
            region,
            "ReceiveMessage",
            {"QueueUrl": queue_url, "MaxNumberOfMessages": 1, "WaitTimeSeconds": 20},
        )
        for message in answer.get("Messages", []):
            print(f"Consumed: {message['Body']}", flush=True)
            call(
                region,
                "DeleteMessage",
                {"QueueUrl": queue_url, "ReceiptHandle": message["ReceiptHandle"]},
            )


if __name__ == "__main__":
    main()
