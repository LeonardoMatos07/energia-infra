output "warnings" {
  description = "Configuration warnings."
  value = compact([
    var.api_origin_domain == "" ? "CloudFront -> ALB over plain HTTP (api_origin_domain is empty). Do not run production like this." : "",
    var.api_domain == "" ? "API only published on the *.cloudfront.net domain (api_domain is empty)." : "",
    var.ses_domain == "" ? "SES is not configured (ses_domain is empty): the newsletter does not send e-mails." : "",
    var.alarm_email == "" ? "Nenhum e-mail inscrito nos alarmes (alarm_email vazio)." : "",
  ])
}

output "api_url" {
  description = "API_URL (public API base, through CloudFront)."
  value       = module.cdn.api_url
}

output "cloudfront_domain_name" {
  value = module.cdn.distribution_domain_name
}

output "alb_dns_name" {
  value = module.api.alb_dns_name
}

output "dns_records" {
  description = "Records to create at the DNS provider (see README)."
  value = concat(
    var.api_domain != "" ? [{ type = "CNAME", name = var.api_domain, value = module.cdn.distribution_domain_name }] : [],
    var.api_origin_domain != "" ? [{ type = "CNAME", name = var.api_origin_domain, value = module.api.alb_dns_name }] : [],
    module.cdn.certificate_validation_records,
    module.api.origin_certificate_validation_records,
    var.ses_domain != "" ? module.email[0].dkim_dns_records : [],
  )
}

output "cognito" {
  description = "Cognito values for energia-api / energia-web."
  value = {
    region            = var.region
    user_pool_id      = module.auth.user_pool_id
    issuer            = module.auth.issuer
    hosted_ui         = module.auth.hosted_ui_domain
    token_url         = module.auth.token_url
    web_client_id     = module.auth.web_client_id
    machine_client_id = module.auth.machine_client_id
    admin_scope       = module.auth.admin_scope
  }
}

output "secrets" {
  description = "Secrets Manager ARNs."
  value = {
    revalidate         = module.api.revalidate_secret_arn
    api_database       = module.database.api_database_secret_arn
    data_warehouse     = module.database.data_warehouse_secret_arn
    rds_master         = module.database.master_user_secret_arn
    cognito_machine    = module.auth.machine_client_secret_arn
    cognito_web_client = module.auth.web_client_secret_arn
    airflow            = module.airflow.airflow_secret_arn
  }
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "lake_bucket" {
  value = module.lake.bucket_name
}

output "database" {
  value = {
    address         = module.database.address
    port            = module.database.port
    name            = module.database.db_name
    master_username = module.database.master_username
  }
}

output "ecs" {
  description = "Values for the energia-api deploy workflow (GitHub variables)."
  value = {
    cluster                   = module.api.cluster_name
    service                   = module.api.service_name
    migration_task_definition = module.api.migration_task_definition_family
    subnets                   = join(",", module.network.public_subnet_ids)
    security_group            = module.api.task_security_group_id
  }
}

output "airflow_instance_id" {
  value = module.airflow.instance_id
}

output "github_role_arns" {
  value = module.github_oidc.role_arns
}

output "alerts_topic_arn" {
  value = module.observability.alerts_topic_arn
}

output "migration_command" {
  description = "Runs `alembic upgrade head` once on Fargate."
  value       = <<-EOT
    aws ecs run-task --region ${var.region} \
      --cluster ${module.api.cluster_name} \
      --task-definition ${module.api.migration_task_definition_family} \
      --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[${join(",", module.network.public_subnet_ids)}],securityGroups=[${module.api.task_security_group_id}],assignPublicIp=ENABLED}"
  EOT
}

output "airflow_port_forward_command" {
  description = "Opens the Airflow UI on http://localhost:8080 through SSM."
  value       = "aws ssm start-session --region ${var.region} --target ${module.airflow.instance_id} --document-name AWS-StartPortForwardingSession --parameters portNumber=8080,localPortNumber=8080"
}
