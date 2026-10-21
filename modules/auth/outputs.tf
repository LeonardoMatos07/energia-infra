output "user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.this.arn
}

output "issuer" {
  description = "OIDC issuer (iss claim) of the user pool."
  value       = local.issuer
}

output "hosted_ui_domain" {
  value = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
}

output "token_url" {
  value = local.token_url
}

output "web_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "machine_client_id" {
  value = aws_cognito_user_pool_client.machine.id
}

output "admin_scope" {
  value = join(" ", aws_cognito_resource_server.api.scope_identifiers)
}

output "machine_client_secret_arn" {
  value = aws_secretsmanager_secret.machine_client.arn
}

output "web_client_secret_arn" {
  value = aws_secretsmanager_secret.web_client.arn
}
