data "aws_caller_identity" "current" {}

locals {
  # Must match the bucket name in terraform/bootstrap
  state_bucket = "quickballot-tfstate-${data.aws_caller_identity.current.account_id}"
}

# GitHub Actions OIDC identity provider. thumbprint_list is optional in
# provider v6; AWS validates the GitHub certificate chain itself.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Role for terraform plan on pull requests. Only workflow runs triggered by a
# pull_request event in the configured repository can assume it.
data "aws_iam_policy_document" "ci_plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:pull_request"]
    }
  }
}

resource "aws_iam_role" "ci_plan" {
  name                 = "${var.project}-ci-plan"
  assume_role_policy   = data.aws_iam_policy_document.ci_plan_trust.json
  max_session_duration = 3600
}

# Read access for terraform plan. The scope covers only the services the
# stacks currently manage; extend it when EKS and RDS are added.
data "aws_iam_policy_document" "ci_plan_read" {
  statement {
    sid = "ReadInfrastructure"
    actions = [
      "ec2:Describe*",
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:GetRegistryScanningConfiguration",
      "route53:Get*",
      "route53:List*",
      "acm:Describe*",
      "acm:Get*",
      "acm:List*",
      "iam:Get*",
      "iam:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadStateBucketConfiguration"
    actions   = ["s3:Get*", "s3:List*"]
    resources = ["arn:aws:s3:::${local.state_bucket}"]
  }
}

resource "aws_iam_role_policy" "ci_plan_read" {
  name   = "infrastructure-read"
  role   = aws_iam_role.ci_plan.id
  policy = data.aws_iam_policy_document.ci_plan_read.json
}

# State access: read state, and create/delete the S3 native lock file only.
# State objects themselves cannot be written.
data "aws_iam_policy_document" "ci_plan_state" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.state_bucket}"]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/*"]
  }

  statement {
    sid       = "ManageStateLock"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "ci_plan_state" {
  name   = "state-bucket-access"
  role   = aws_iam_role.ci_plan.id
  policy = data.aws_iam_policy_document.ci_plan_state.json
}
