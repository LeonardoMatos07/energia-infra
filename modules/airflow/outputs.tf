output "instance_id" {
  value = aws_instance.this.id
}

output "instance_arn" {
  value = aws_instance.this.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "airflow_secret_arn" {
  value = aws_secretsmanager_secret.airflow.arn
}

output "config_parameter_name" {
  value = aws_ssm_parameter.config.name
}

output "repo_dir" {
  value = local.repo_dir
}
