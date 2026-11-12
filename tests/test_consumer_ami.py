import json
from os import path as osp, remove
from shutil import rmtree
from textwrap import dedent
from typing import Any

from tests.conftest import (
    AL2023_ECS_IMAGES,
    AMAZON,
    LOG,
    TERRAFORM_ROOT_DIR,
    terraform,
)

# Canonical's Ubuntu 24.04 images, which name their root device /dev/sda1: not
# the default image's name.
CANONICAL = "099720109477"
UBUNTU_IMAGES = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"

LAUNCH_TEMPLATE = "module.test.module.asg.aws_launch_template.consumer"


def _newest_image(ec2: Any, owner: str, name: str) -> dict:
    """
    Find the newest x86_64 image of an owner by its name's pattern.

    :param ec2: A boto3 EC2 client.
    :param owner: The images' owner, an account id.
    :param name: The images' name pattern.
    :return: The image, as DescribeImages answers it.
    """
    images = ec2.describe_images(
        Owners=[owner],
        Filters=[
            {"Name": "name", "Values": [name]},
            {"Name": "architecture", "Values": ["x86_64"]},
            {"Name": "virtualization-type", "Values": ["hvm"]},
        ],
    )["Images"]
    return max(images, key=lambda image: image["CreationDate"])


def test_consumer_ami_id(
    service_network,
    test_role_arn,
    aws_region,
    boto3_session,
    tmp_path,
):
    """
    Plans the module with ``consumer_ami_id`` set to an image whose root device
    has another name than the default image's.

    The launch template must take that image, and map that image's root device,
    so the instance's root volume is sized and encrypted rather than joined by
    another volume. Plans only: it creates nothing.
    """
    ec2 = boto3_session.client("ec2", region_name=aws_region)
    default_image = _newest_image(ec2, AMAZON, AL2023_ECS_IMAGES)
    image = _newest_image(ec2, CANONICAL, UBUNTU_IMAGES)
    LOG.info(
        "The default image %s maps %s; consumer_ami_id %s (%s) maps %s",
        default_image["ImageId"],
        default_image["RootDeviceName"],
        image["ImageId"],
        image["Name"],
        image["RootDeviceName"],
    )
    # Otherwise the test couldn't tell which image named the device.
    assert image["RootDeviceName"] != default_image["RootDeviceName"]

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "sqs-ecs-ami")
    for state_path in [
        osp.join(terraform_module_dir, ".terraform"),
        osp.join(terraform_module_dir, ".terraform.lock.hcl"),
    ]:
        if osp.isdir(state_path):
            rmtree(state_path)
        elif osp.isfile(state_path):
            remove(state_path)

    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    image_id = image["ImageId"]
    with open(osp.join(terraform_module_dir, "terraform.tfvars"), "w") as fp:
        fp.write(dedent(f"""
                    region              = "{aws_region}"
                    consumer_subnet_ids = {json.dumps(subnet_private_ids)}
                    consumer_ami_id     = "{image_id}"
                    """))
        if test_role_arn:
            fp.write(f'role_arn = "{test_role_arn}"\n')

    plan_path = str(tmp_path / "ami.plan")
    terraform(terraform_module_dir, "init", "-input=false", "-no-color")
    terraform(
        terraform_module_dir,
        "plan",
        "-var-file=terraform.tfvars",
        "-input=false",
        "-no-color",
        f"-out={plan_path}",
    )
    plan = json.loads(terraform(terraform_module_dir, "show", "-json", plan_path))
    launch_template = next(
        change["change"]["after"]
        for change in plan["resource_changes"]
        if change["address"] == LAUNCH_TEMPLATE
    )
    LOG.info(
        "The planned launch template: image %s, block devices %s",
        launch_template["image_id"],
        json.dumps(launch_template["block_device_mappings"]),
    )
    assert launch_template["image_id"] == image["ImageId"]
    assert [
        mapping["device_name"] for mapping in launch_template["block_device_mappings"]
    ] == [image["RootDeviceName"]]
