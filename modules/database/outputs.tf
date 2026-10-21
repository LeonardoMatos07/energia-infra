output "instance_identifier" {
  value = aws_db_instance.this.identifier
}

output "address" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = var.db_name
}

output "master_username" {
  value = var.master_username
}

output "master_user_secret_arn" {
  description = "Secret (managed by RDS) with the master username/password."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "api_database_secret_arn" {
  value = aws_secretsmanager_secret.api_database.arn
}

output "data_warehouse_secret_arn" {
  value = aws_secretsmanager_secret.data_warehouse.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
