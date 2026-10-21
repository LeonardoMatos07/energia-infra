data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id
  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : (
    "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
  )

  subjects = {
    api = [
      "repo:${var.github_owner}/${var.api_repository}:ref:refs/heads/main",
      "repo:${var.github_owner}/${var.api_repository}:environment:${var.production_environment}",
    ]
    data = [
      "repo:${var.github_owner}/${var.data_repository}:ref:refs/heads/main",
      "repo:${var.github_owner}/${var.data_repository}:environment:${var.production_environment}",
    ]
    infra_plan = [
      "repo:${var.github_owner}/${var.infra_repository}:pull_request",
      "repo:${var.github_owner}/${var.infra_repository}:ref:refs/heads/main",
    ]
    infra_apply = [
      "repo:${var.github_owner}/${var.infra_repository}:environment:${var.production_environment}",
    ]
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "trust" {
  for_each = local.subjects

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = local.subjects

  name                 = "${var.name_prefix}-github-${replace(each.key, "_", "-")}"
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "api" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [var.api_ecr_repository_arn]
  }

  statement {
    sid       = "DeployService"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = [var.ecs_service_arn]
  }

  statement {
    sid     = "RunMigration"
    actions = ["ecs:RunTask"]
    resources = [
      "arn:aws:ecs:${local.region}:${local.account_id}:task-definition/${var.migration_task_family}:*",
      "arn:aws:ecs:${local.region}:${local.account_id}:task-definition/${var.migration_task_family}",
    ]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [var.ecs_cluster_arn]
    }
  }

  statement {
    sid       = "WatchTasks"
    actions   = ["ecs:DescribeTasks", "ecs:ListTasks"]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [var.ecs_cluster_arn]
    }
  }

  statement {
    sid       = "DescribeTaskDefinitions"
    actions   = ["ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = var.ecs_task_role_arns

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "ReadMigrationLogs"
    actions   = ["logs:GetLogEvents", "logs:FilterLogEvents"]
    resources = ["${var.api_log_group_arn}:*"]
  }
}

resource "aws_iam_role_policy" "api" {
  name   = "deploy"
  role   = aws_iam_role.this["api"].id
  policy = data.aws_iam_policy_document.api.json
}

data "aws_iam_policy_document" "data" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [var.data_ecr_repository_arn]
  }

  statement {
    sid     = "SendDeployCommand"
    actions = ["ssm:SendCommand"]
    resources = [
      var.airflow_instance_arn,
      "arn:aws:ssm:${local.region}::document/AWS-RunShellScript",
    ]
  }

  statement {
    sid = "FollowDeployCommand"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:ListCommands",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "data" {
  name   = "deploy"
  role   = aws_iam_role.this["data"].id
  policy = data.aws_iam_policy_document.data.json
}

resource "aws_iam_role_policy_attachment" "infra_plan_readonly" {
  role       = aws_iam_role.this["infra_plan"].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "infra_plan" {
  statement {
    sid       = "StateRead"
    actions   = ["s3:ListBucket", "s3:GetObject"]
    resources = [var.state_bucket_arn, "${var.state_bucket_arn}/*"]
  }

  statement {
    sid       = "StateLock"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/*.tflock"]
  }

  statement {
    sid       = "RefreshSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.secrets_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "infra_plan" {
  name   = "terraform-plan"
  role   = aws_iam_role.this["infra_plan"].id
  policy = data.aws_iam_policy_document.infra_plan.json
}

resource "aws_iam_role_policy_attachment" "infra_apply_admin" {
  role       = aws_iam_role.this["infra_apply"].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
