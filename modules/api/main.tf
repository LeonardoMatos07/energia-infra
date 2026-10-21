data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

locals {
  https_enabled = var.origin_domain != ""
  listener_port = local.https_enabled ? 443 : 80
  region        = data.aws_region.current.region

  environment = merge(
    {
      ENVIRONMENT            = "prod"
      WEB_URL                = var.web_url
      COGNITO_REGION         = local.region
      COGNITO_USER_POOL_ID   = var.cognito_user_pool_id
      COGNITO_APP_CLIENT_IDS = join(",", var.cognito_app_client_ids)
    },
    var.extra_environment,
  )
}

resource "random_password" "revalidate" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "revalidate" {
  name                    = "${var.secrets_prefix}/api/revalidate-secret"
  description             = "REVALIDATE_SECRET shared by energia-api and energia-web (Vercel)"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "revalidate" {
  secret_id     = aws_secretsmanager_secret.revalidate.id
  secret_string = random_password.revalidate.result
}

resource "random_password" "origin_verify" {
  length  = 40
  special = false
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb"
  description = "ALB: only CloudFront origin-facing ranges"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "CloudFront origin-facing"
  ip_protocol       = "tcp"
  from_port         = local.listener_port
  to_port           = local.listener_port
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To API tasks"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.tasks.id
}

resource "aws_security_group" "tasks" {
  name        = "${var.name_prefix}-api-tasks"
  description = "API tasks: inbound only from the ALB"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-api-tasks" }
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "From ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "tasks_all" {
  security_group_id = aws_security_group.tasks.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_acm_certificate" "origin" {
  count = local.https_enabled ? 1 : 0

  domain_name       = var.origin_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "origin" {
  count = local.https_enabled ? 1 : 0

  certificate_arn = aws_acm_certificate.origin[0].arn
}

resource "aws_lb" "this" {
  name               = var.name_prefix
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  drop_invalid_header_fields = true
  idle_timeout               = 60
}

resource "aws_lb_target_group" "api" {
  name                 = "${var.name_prefix}-api"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = local.listener_port
  protocol          = local.https_enabled ? "HTTPS" : "HTTP"
  ssl_policy        = local.https_enabled ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null
  certificate_arn   = local.https_enabled ? aws_acm_certificate_validation.origin[0].certificate_arn : null

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = "{\"detail\": \"Direct access is not allowed\"}"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "from_cloudfront" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 10

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.origin_verify.result]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-api-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.api_database_secret_arn,
      var.master_user_secret_arn,
      aws_secretsmanager_secret.revalidate.arn,
    ]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "read-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-api-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "task_ses" {
  statement {
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["arn:aws:ses:${local.region}:${data.aws_caller_identity.current.account_id}:identity/*"]
  }
}

resource "aws_iam_role_policy" "task_ses" {
  count = var.ses_enabled ? 1 : 0

  name   = "send-newsletter"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_ses.json
}

resource "aws_ecs_cluster" "this" {
  name = var.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${var.image_repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [for name, value in local.environment : { name = name, value = value }]

    secrets = [
      { name = "DATABASE_URL", valueFrom = "${var.api_database_secret_arn}:url::" },
      { name = "REVALIDATE_SECRET", valueFrom = aws_secretsmanager_secret.revalidate.arn },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_name
        awslogs-region        = local.region
        awslogs-stream-prefix = "api"
      }
    }
  }])
}

locals {
  migrate_script = <<-EOT
    set -e
    DATABASE_URL="$(python -c 'import os, urllib.parse as p; e = os.environ; print(e["DB_URL_SCHEME"] + "://" + p.quote(e["DB_USER"], safe="") + ":" + p.quote(e["DB_PASSWORD"], safe="") + "@" + e["DB_HOST"] + ":" + e["DB_PORT"] + "/" + e["DB_NAME"] + "?" + e["DB_URL_PARAMS"])')"
    export DATABASE_URL
    exec alembic upgrade head
  EOT
}

resource "aws_ecs_task_definition" "migrate" {
  family                   = "${var.name_prefix}-api-migrate"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([{
    name       = "migrate"
    image      = "${var.image_repository_url}:${var.image_tag}"
    essential  = true
    entryPoint = ["sh", "-c"]
    command    = [local.migrate_script]

    environment = [for name, value in merge(local.environment, {
      DB_URL_SCHEME = var.database_url_scheme
      DB_URL_PARAMS = var.database_url_params
      DB_HOST       = var.db_host
      DB_PORT       = tostring(var.db_port)
      DB_NAME       = var.db_name
    }) : { name = name, value = value }]

    secrets = [
      { name = "DB_USER", valueFrom = "${var.master_user_secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.master_user_secret_arn}:password::" },
      { name = "REVALIDATE_SECRET", valueFrom = aws_secretsmanager_secret.revalidate.arn },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_name
        awslogs-region        = local.region
        awslogs-stream-prefix = "migrate"
      }
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "${var.name_prefix}-api"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener_rule.from_cloudfront]
}
