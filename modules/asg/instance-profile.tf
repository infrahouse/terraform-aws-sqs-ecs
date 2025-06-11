data "aws_iam_policy" "ssm" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy" "ecs" {
  name = "AmazonEC2ContainerServiceforEC2Role"
}

data "aws_iam_policy_document" "required_permissions" {
  statement {
    actions = [
      "sts:GetCallerIdentity",
      "ec2:DescribeInstances",
    ]
    resources = [
      "*"
    ]
  }
}

resource "random_string" "profile-suffix" {
  length  = 12
  special = false
}

module "instance-profile" {
  source       = "registry.infrahouse.com/infrahouse/instance-profile/aws"
  version      = "1.8.1"
  permissions  = data.aws_iam_policy_document.required_permissions.json
  profile_name = "sqs-ecs-${random_string.profile-suffix.result}"
  extra_policies = merge(
    {
      ssm : data.aws_iam_policy.ssm.arn
      ecs : data.aws_iam_policy.ecs.arn
    },
    var.extra_policies
  )
}
