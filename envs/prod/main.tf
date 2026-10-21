data "aws_caller_identity" "current" {}

locals {
  name_prefix    = "${var.project}-${var.environment}"
  secrets_prefix = "${var.project}/${var.environment}"
  account_id     = data.aws_caller_identity.current.account_id
  lake_bucket    = "${var.project}-lake-${local.account_id}"
  state_bucket   = coalesce(var.state_bucket_name, "${var.project}-tfstate-${local.account_id}")
}

check "api_origin_https" {
  assert {
    condition     = var.api_origin_domain != ""
    error_message = "WARNING: api_origin_domain is empty. CloudFront talks to the ALB over plain HTTP (no TLS on the internet). Use it for tests only; set api_origin_domain before production."
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix = local.name_prefix
}

module "lake" {
  source = "../../modules/lake"

  bucket_name = local.lake_bucket
}

module "ecr" {
  source = "../../modules/ecr"
}

module "observability" {
  source = "../../modules/observability"

  name_prefix            = local.name_prefix
  log_prefix             = local.secrets_prefix
  log_retention_days     = var.log_retention_days
  alarm_email            = var.alarm_email
  alb_arn_suffix         = module.api.alb_arn_suffix
  ecs_cluster_name       = module.api.cluster_name
  ecs_service_name       = module.api.service_name
  db_instance_identifier = module.database.instance_identifier
  airflow_instance_id    = module.airflow.instance_id
}

module "auth" {
  source = "../../modules/auth"

  name_prefix       = local.name_prefix
  secrets_prefix    = local.secrets_prefix
  domain_prefix     = var.cognito_domain_prefix
  web_callback_urls = var.web_callback_urls
  web_logout_urls   = var.web_logout_urls
}

module "database" {
  source = "../../modules/database"

  name_prefix         = local.name_prefix
  secrets_prefix      = local.secrets_prefix
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  instance_class      = var.db_instance_class
  multi_az            = var.db_multi_az
  db_name             = var.db_name
  database_url_scheme = var.database_url_scheme

  allowed_security_group_ids = {
    api     = module.api.task_security_group_id
    airflow = module.airflow.security_group_id
  }
}

module "api" {
  source = "../../modules/api"

  name_prefix          = local.name_prefix
  secrets_prefix       = local.secrets_prefix
  vpc_id               = module.network.vpc_id
  public_subnet_ids    = module.network.public_subnet_ids
  origin_domain        = var.api_origin_domain
  image_repository_url = module.ecr.repository_urls["energia-api"]
  image_tag            = var.api_image_tag
  cpu                  = var.api_cpu
  memory               = var.api_memory
  cpu_architecture     = var.api_cpu_architecture
  desired_count        = var.api_desired_count
  log_group_name       = module.observability.api_log_group_name
  web_url              = var.web_url
  extra_environment    = var.api_extra_environment

  cognito_user_pool_id   = module.auth.user_pool_id
  cognito_app_client_ids = [module.auth.web_client_id, module.auth.machine_client_id]

  api_database_secret_arn = module.database.api_database_secret_arn
  master_user_secret_arn  = module.database.master_user_secret_arn
  db_host                 = module.database.address
  db_port                 = module.database.port
  db_name                 = module.database.db_name
  database_url_scheme     = var.database_url_scheme

  ses_enabled = var.ses_domain != ""
}

module "cdn" {
  source = "../../modules/cdn"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix                = local.name_prefix
  api_domain                 = var.api_domain
  https_origin               = var.api_origin_domain != ""
  origin_domain              = var.api_origin_domain
  alb_dns_name               = module.api.alb_dns_name
  origin_verify_header_value = module.api.origin_verify_header_value
}

module "airflow" {
  source = "../../modules/airflow"

  name_prefix               = local.name_prefix
  secrets_prefix            = local.secrets_prefix
  vpc_id                    = module.network.vpc_id
  subnet_id                 = module.network.public_subnet_ids[0]
  instance_type             = var.airflow_instance_type
  root_volume_size_gb       = var.airflow_root_volume_size_gb
  lake_bucket_name          = module.lake.bucket_name
  lake_bucket_arn           = module.lake.bucket_arn
  ecr_repository_arn        = module.ecr.repository_arns["energia-data"]
  warehouse_secret_arn      = module.database.data_warehouse_secret_arn
  machine_client_secret_arn = module.auth.machine_client_secret_arn
  api_url                   = module.cdn.api_url
  log_group_name            = module.observability.airflow_log_group_name
}

module "email" {
  source = "../../modules/email"
  count  = var.ses_domain != "" ? 1 : 0

  domain = var.ses_domain
}

module "github_oidc" {
  source = "../../modules/github_oidc"

  name_prefix          = local.name_prefix
  secrets_prefix       = local.secrets_prefix
  create_oidc_provider = var.create_github_oidc_provider
  github_owner         = var.github_owner

  api_ecr_repository_arn  = module.ecr.repository_arns["energia-api"]
  data_ecr_repository_arn = module.ecr.repository_arns["energia-data"]
  ecs_cluster_arn         = module.api.cluster_arn
  ecs_service_arn         = module.api.service_arn
  migration_task_family   = module.api.migration_task_definition_family
  ecs_task_role_arns      = [module.api.execution_role_arn, module.api.task_role_arn]
  api_log_group_arn       = module.observability.api_log_group_arn
  airflow_instance_arn    = module.airflow.instance_arn
  state_bucket_arn        = "arn:aws:s3:::${local.state_bucket}"
}
