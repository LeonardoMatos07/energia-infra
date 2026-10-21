output "https_enabled" {
  value = local.https_enabled
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.api.arn_suffix
}

output "origin_verify_header_value" {
  value     = random_password.origin_verify.result
  sensitive = true
}

output "origin_certificate_validation_records" {
  description = "DNS records that validate the ALB origin certificate."
  value = local.https_enabled ? [
    for o in aws_acm_certificate.origin[0].domain_validation_options : {
      type  = o.resource_record_type
      name  = o.resource_record_name
      value = o.resource_record_value
    }
  ] : []
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "service_name" {
  value = aws_ecs_service.api.name
}

output "service_arn" {
  value = aws_ecs_service.api.id
}

output "task_security_group_id" {
  value = aws_security_group.tasks.id
}

output "task_definition_family" {
  value = aws_ecs_task_definition.api.family
}

output "migration_task_definition_family" {
  value = aws_ecs_task_definition.migrate.family
}

output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "revalidate_secret_arn" {
  value = aws_secretsmanager_secret.revalidate.arn
}
