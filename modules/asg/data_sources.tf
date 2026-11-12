data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_default_tags" "provider" {}

data "aws_subnet" "selected" {
  id = var.subnet_ids[0]
}

# The default image: the newest Amazon Linux 2023 ECS-optimized one, found by
# the same filters and owner as infrahouse/ecs/aws's, so a service built from
# both modules runs one build.
data "aws_ami" "ecs" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["591542846629"] # Amazon
}

# The image var.ami_id names, read for its root device's name: images name
# theirs differently (/dev/xvda, /dev/sda1), and a launch template that maps
# another name adds a volume instead of sizing and encrypting the root one.
data "aws_ami" "selected" {
  count = var.ami_id == null ? 0 : 1

  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

data "aws_ec2_instance_type" "ecs" {
  instance_type = var.instance_type
}



data "cloudinit_config" "ecs" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = join(
      "\n",
      [
        "#cloud-config",
        yamlencode(
          merge(
            var.users == null ? {} : {
              users : var.users
            },
            {
              write_files : concat(
                [
                  {
                    path : "/etc/ecs/ecs.config"
                    permissions : "0644"
                    content : join(
                      "\n",
                      [
                        "ECS_CLUSTER=${var.service_name}",
                        "ECS_LOGLEVEL=debug",
                        "ECS_ALLOW_OFFHOST_INTROSPECTION_ACCESS=true"
                      ]
                    )
                  }
                ],
                var.enable_cloudwatch_logs ? [
                  {
                    path : var.cloudwatch_agent_config_path
                    permissions : "0644"
                    content : templatefile(
                      "${path.module}/assets/cloudwatch_agent_config.tftpl",
                      {
                        syslog_group_name : aws_cloudwatch_log_group.ecs_ec2_syslog[0].name
                        dmesg_group_name : aws_cloudwatch_log_group.ecs_ec2_dmesg[0].name
                      }
                    )
                  }
                ] : [],
                var.enable_vector_agent ? [
                  {
                    path : var.vector_agent_config_path
                    permissions : "0644"
                    content : var.vector_agent_config != null ? var.vector_agent_config : templatefile(
                      "${path.module}/assets/vector_agent_config.yaml.tftmpl",
                      {
                        environment                = var.environment
                        aws_region                 = data.aws_region.current.name
                        vector_aggregator_endpoint = var.vector_aggregator_endpoint
                      }
                    )
                  }
                ] : [],
                var.extra_files
              )
            },
            # The files the CloudWatch agent ships, /var/log/messages and
            # /var/log/dmesg. Amazon Linux 2 writes both; Amazon Linux 2023
            # writes neither: it has no rsyslog, and nothing saves the kernel's
            # boot messages. bootcmd runs at every boot, as Amazon Linux 2's
            # dmesg service does.
            var.enable_cloudwatch_logs ? {
              bootcmd : ["dmesg > /var/log/dmesg"]
            } : {},
            {
              "runcmd" : concat(
                [
                  "fallocate -l ${data.aws_ec2_instance_type.ecs.memory_size * 2}M /swapfile",
                  "chmod 600 /swapfile",
                  "mkswap /swapfile",
                  "swapon /swapfile"
                ],
                # Installed and started in one script, in that order. yum is dnf
                # on 2023, and Amazon Linux 2 has rsyslog already.
                var.enable_cloudwatch_logs ? [
                  "yum install -y rsyslog",
                  "systemctl enable --now rsyslog"
                ] : []
              )
            }
          )

        )
      ]
    )
  }
}
