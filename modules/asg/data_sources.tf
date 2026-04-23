data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_default_tags" "provider" {}

data "aws_subnet" "selected" {
  id = var.subnet_ids[0]
}

data "aws_ami" "ecs" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*"]
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
            {
              "runcmd" : [
                "fallocate -l ${data.aws_ec2_instance_type.ecs.memory_size * 2}M /swapfile",
                "chmod 600 /swapfile",
                "mkswap /swapfile",
                "swapon /swapfile"
              ]
            }
          )

        )
      ]
    )
  }
}
