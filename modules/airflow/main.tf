data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  region   = data.aws_region.current.region
  repo_dir = "/opt/energia-data"
}

resource "random_password" "airflow_admin" {
  length  = 24
  special = false
}

resource "random_password" "airflow_jwt" {
  length  = 48
  special = false
}

resource "random_bytes" "fernet" {
  length = 32
}

resource "aws_secretsmanager_secret" "airflow" {
  name                    = "${var.secrets_prefix}/data/airflow"
  description             = "Airflow fernet key, JWT secret and admin credentials"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "airflow" {
  secret_id = aws_secretsmanager_secret.airflow.id
  secret_string = jsonencode({
    fernet_key     = replace(replace(random_bytes.fernet.base64, "+", "-"), "/", "_")
    jwt_secret     = random_password.airflow_jwt.result
    admin_username = "admin"
    admin_password = random_password.airflow_admin.result
  })
}

resource "aws_ssm_parameter" "config" {
  name        = "/${var.secrets_prefix}/data/config"
  description = "Non-secret settings for the energia-data .env"
  type        = "String"
  value = jsonencode({
    aws_account_id = data.aws_caller_identity.current.account_id
    lake_bucket    = var.lake_bucket_name
    api_url        = var.api_url
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-airflow"
  description = "Airflow host: no inbound, all outbound"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-airflow" }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound (ONS, S3, ECR, SSM, Secrets Manager, API)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name_prefix}-airflow"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "this" {
  statement {
    sid       = "LakeList"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [var.lake_bucket_arn]
  }

  statement {
    sid       = "LakeReadWrite"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
    resources = ["${var.lake_bucket_arn}/*"]
  }

  statement {
    sid     = "ReadOwnSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.warehouse_secret_arn,
      var.machine_client_secret_arn,
      aws_secretsmanager_secret.airflow.arn,
    ]
  }

  statement {
    sid       = "ReadConfig"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.config.arn]
  }

  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "energia-data"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-airflow"
  role = aws_iam_role.this.name
}

locals {
  cloudwatch_config = {
    agent = { run_as_user = "root" }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "${local.repo_dir}/logs/dag_id=*/**/*.log"
              log_group_name  = var.log_group_name
              log_stream_name = "{instance_id}/tasks"
            },
            {
              file_path       = "/var/log/energia-bootstrap.log"
              log_group_name  = var.log_group_name
              log_stream_name = "{instance_id}/bootstrap"
            },
          ]
        }
      }
    }
  }

  user_data = templatefile("${path.module}/files/user_data.sh.tftpl", {
    compose_version          = var.compose_version
    repo_dir                 = local.repo_dir
    region                   = local.region
    config_parameter         = aws_ssm_parameter.config.name
    warehouse_secret_id      = var.warehouse_secret_arn
    machine_client_secret_id = var.machine_client_secret_arn
    airflow_secret_id        = aws_secretsmanager_secret.airflow.arn
    render_script_b64        = filebase64("${path.module}/files/render-airflow-env.sh")
    cloudwatch_config_b64    = base64encode(jsonencode(local.cloudwatch_config))
  })
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.this.name
  disable_api_termination     = true
  monitoring                  = false

  user_data                   = local.user_data
  user_data_replace_on_change = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${var.name_prefix}-airflow" }

  lifecycle {
    ignore_changes = [ami]
  }

  depends_on = [aws_secretsmanager_secret_version.airflow]
}
