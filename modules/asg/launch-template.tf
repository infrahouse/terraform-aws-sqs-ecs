resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
}

resource "aws_key_pair" "this" {
  key_name_prefix = "${var.service_name}-deployer-generated-"
  public_key      = tls_private_key.key_pair.public_key_openssh
  tags            = local.default_module_tags
}

resource "aws_launch_template" "consumer" {
  name_prefix   = "${var.service_name}-consumer-"
  instance_type = var.instance_type
  key_name      = var.keypair_name == null ? aws_key_pair.this.key_name : var.keypair_name
  image_id      = local.ami_id
  iam_instance_profile {
    arn = module.instance-profile.instance_profile_arn
  }
  block_device_mappings {
    device_name = data.aws_ami.ecs.root_device_name
    ebs {
      volume_size           = var.root_volume_size
      delete_on_termination = true
      encrypted             = true
    }
  }
  metadata_options {
    http_tokens            = "required"
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
  user_data = data.cloudinit_config.ecs.rendered
  vpc_security_group_ids = [
    aws_security_group.consumer.id
  ]
  tags = local.default_module_tags
  tag_specifications {
    resource_type = "volume"
    tags = merge(
      data.aws_default_tags.provider.tags,
      local.default_module_tags
    )
  }
  tag_specifications {
    resource_type = "network-interface"
    tags = merge(
      data.aws_default_tags.provider.tags,
      local.default_module_tags
    )
  }

}

