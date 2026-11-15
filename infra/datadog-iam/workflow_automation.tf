# Registers the app key used by Terraform so it can manage Action connections.
resource "datadog_app_key_registration" "this" {
  id = var.datadog_app_key_id
}

resource "datadog_action_connection" "aws" {
  name = "${local.prefix}-aws"
  tags = ["env:demo", "team:web", "service:demo-app"]

  aws {
    assume_role {
      account_id = local.aws_account_id
      role       = "${local.prefix}-workflow-automation"
    }
  }

  depends_on = [datadog_app_key_registration.this]
}

data "aws_iam_policy_document" "workflow_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${datadog_action_connection.aws.aws.assume_role.principal_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [datadog_action_connection.aws.aws.assume_role.external_id]
    }
  }
}

resource "aws_iam_role" "workflow" {
  name                 = "${local.prefix}-workflow-automation"
  description          = "Assumed by Datadog Workflow Automation for scoped demo remediation"
  assume_role_policy   = data.aws_iam_policy_document.workflow_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "workflow_remediation" {
  statement {
    sid    = "S3PublicAccessBlockDemoBuckets"
    effect = "Allow"
    actions = [
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
    ]
    resources = ["arn:aws:s3:::${local.prefix}-*"]
  }

  statement {
    sid       = "DescribeSecurityGroups"
    effect    = "Allow"
    actions   = ["ec2:DescribeSecurityGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "RevokeIngressDemoSecurityGroups"
    effect    = "Allow"
    actions   = ["ec2:RevokeSecurityGroupIngress"]
    resources = ["arn:aws:ec2:${local.aws_region}:${local.aws_account_id}:security-group/*"]

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/Name"
      values   = ["${local.prefix}-*"]
    }

    condition {
      test     = "ArnEquals"
      variable = "ec2:Vpc"
      values   = [data.aws_vpc.demo.arn]
    }
  }
}

resource "aws_iam_role_policy" "workflow_remediation" {
  name   = "${local.prefix}-workflow-remediation"
  role   = aws_iam_role.workflow.id
  policy = data.aws_iam_policy_document.workflow_remediation.json
}
