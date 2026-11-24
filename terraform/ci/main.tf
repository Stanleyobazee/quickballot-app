data "aws_caller_identity" "current" {}

locals {
  # Must match the bucket name in terraform/bootstrap
  state_bucket = "quickballot-tfstate-${data.aws_caller_identity.current.account_id}"

  github_owner = split("/", var.github_repository)[0]
  github_repo  = split("/", var.github_repository)[1]

  ecr_repository_arns = [
    for name in ["vote-ui", "vote-api", "results-api"] :
    "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.project}/${name}"
  ]
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

    # The subject contains the permanent numeric IDs of the owner and the
    # repository, so a renamed or recreated repository cannot assume the role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_owner}@${var.github_owner_id}/${local.github_repo}@${var.github_repository_id}:pull_request"]
    }
  }
}

resource "aws_iam_role" "ci_plan" {
  name                 = "${var.project}-ci-plan"
  assume_role_policy   = data.aws_iam_policy_document.ci_plan_trust.json
  max_session_duration = 3600
}

# Read access for terraform plan. The scope covers only the services the
# stacks manage (EC2/VPC, ECR, RDS, Route 53, ACM, IAM, EKS and its log group);
# extend it when a stack adds a service.
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
      "rds:Describe*",
      "rds:ListTagsForResource",
      "eks:Describe*",
      "eks:List*",
      "logs:Describe*",
      "logs:ListTagsForResource",
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

# Role for pushing the application images to ECR. It is separate from the plan
# role because it can write: the plan role is read-only and any pull request can
# assume it, while this role is limited to workflow runs on the main branch.
data "aws_iam_policy_document" "ci_push_trust" {
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
      values   = ["repo:${local.github_owner}@${var.github_owner_id}/${local.github_repo}@${var.github_repository_id}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "ci_push" {
  name                 = "${var.project}-ci-push"
  assume_role_policy   = data.aws_iam_policy_document.ci_push_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "ci_push" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PushApplicationImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
      "ecr:StartImageScan",
    ]
    resources = local.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "ci_push" {
  name   = "ecr-push"
  role   = aws_iam_role.ci_push.id
  policy = data.aws_iam_policy_document.ci_push.json
}
