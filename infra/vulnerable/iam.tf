resource "aws_iam_user" "overprivileged" {
  name = "${local.prefix}-overprivileged"
}

data "aws_iam_policy_document" "broad_access" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "broad_access" {
  name   = "${local.prefix}-broad-access"
  user   = aws_iam_user.overprivileged.name
  policy = data.aws_iam_policy_document.broad_access.json
}
