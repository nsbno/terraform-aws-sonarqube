data "aws_iam_policy_document" "kms_for_task" {
  statement {
    effect = "Allow"
    actions = ["kms:*"]
    resources = [var.parameters_key_arn]
  }
}

data "aws_iam_policy_document" "ssm_for_task" {
  statement {
    effect = "Allow"
    actions = ["ssm:DescribeParameters"]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.name_prefix}/*"
    ]
  }
}


