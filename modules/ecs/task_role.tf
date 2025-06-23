data "aws_iam_policy_document" "task_role_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      values = [
        data.aws_caller_identity.current.account_id
      ]
      variable = "aws:SourceAccount"
    }
    condition {
      test = "ArnLike"
      values = [
        "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      ]
      variable = "aws:SourceArn"
    }
  }
}

data "aws_iam_policy_document" "task_role_permissions" {
  statement {
    actions = [
      "sts:GetCallerIdentity",
      "ec2:DescribeInstances",
    ]
    resources = [
      "*"
    ]
  }
  statement {
    actions = [
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:ReceiveMessage",
    ]
    resources = [
      data.aws_sqs_queue.current.arn
    ]
  }
}

resource "aws_iam_policy" "task_role" {
  name_prefix = "${var.service_name}-consumer-"
  policy      = data.aws_iam_policy_document.task_role_permissions.json
}

resource "aws_iam_role" "task_role" {
  name_prefix        = "${var.service_name}-consumer-"
  assume_role_policy = data.aws_iam_policy_document.task_role_assume.json
}

resource "aws_iam_role_policy_attachment" "task_role" {
  policy_arn = aws_iam_policy.task_role.arn
  role       = aws_iam_role.task_role.name
}

## User provided permissions
resource "aws_iam_role_policy_attachment" "task_role_user_policy" {
  for_each   = var.task_role_extra_policies
  role       = aws_iam_role.task_role.name
  policy_arn = each.value
}
