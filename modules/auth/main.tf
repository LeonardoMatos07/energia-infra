data "aws_region" "current" {}

resource "aws_cognito_user_pool" "this" {
  name = var.name_prefix

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  mfa_configuration = "ON"

  software_token_mfa_configuration {
    enabled = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 3
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  deletion_protection = "ACTIVE"
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Administradores do portal (acesso a /v1/admin/*)"
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_resource_server" "api" {
  identifier   = "energia-api"
  name         = "energia-api"
  user_pool_id = aws_cognito_user_pool.this.id

  scope {
    scope_name        = "admin"
    scope_description = "Acesso administrativo a /v1/admin/*"
  }
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "energia-web"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = var.web_callback_urls
  logout_urls                          = var.web_logout_urls

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 12

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "hours"
  }
}

resource "aws_cognito_user_pool_client" "machine" {
  name         = "energia-data"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = aws_cognito_resource_server.api.scope_identifiers
  supported_identity_providers         = ["COGNITO"]
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH"]

  access_token_validity = 60

  token_validity_units {
    access_token = "minutes"
  }
}

locals {
  issuer    = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
  token_url = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com/oauth2/token"
}

resource "aws_secretsmanager_secret" "machine_client" {
  name                    = "${var.secrets_prefix}/data/cognito-machine-client"
  description             = "Cognito client credentials used by energia-data to call the admin API"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "machine_client" {
  secret_id = aws_secretsmanager_secret.machine_client.id
  secret_string = jsonencode({
    client_id     = aws_cognito_user_pool_client.machine.id
    client_secret = aws_cognito_user_pool_client.machine.client_secret
    token_url     = local.token_url
    scope         = join(" ", aws_cognito_resource_server.api.scope_identifiers)
  })
}

resource "aws_secretsmanager_secret" "web_client" {
  name                    = "${var.secrets_prefix}/web/cognito-web-client"
  description             = "Cognito web client (Auth.js) id/secret, to be copied to Vercel"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "web_client" {
  secret_id = aws_secretsmanager_secret.web_client.id
  secret_string = jsonencode({
    client_id     = aws_cognito_user_pool_client.web.id
    client_secret = aws_cognito_user_pool_client.web.client_secret
    issuer        = local.issuer
  })
}
