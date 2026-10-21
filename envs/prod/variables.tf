variable "region" {
  type    = string
  default = "sa-east-1"
}

variable "project" {
  type    = string
  default = "energia"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "state_bucket_name" {
  description = "Terraform state bucket (for the plan role). Empty = <project>-tfstate-<account_id>, as created by bootstrap/."
  type        = string
  default     = ""
}

variable "web_url" {
  description = "Public URL of the portal on Vercel (WEB_URL), e.g. https://energia.com.br."
  type        = string

  validation {
    condition     = can(regex("^https?://[^/]+$", var.web_url))
    error_message = "web_url must be scheme + host, without a trailing slash."
  }
}

variable "api_domain" {
  description = "Public API hostname served by CloudFront (e.g. api.energia.com.br). Empty = use the *.cloudfront.net name."
  type        = string
  default     = ""
}

variable "api_origin_domain" {
  description = "Hostname pointing to the ALB, used by CloudFront to reach it over HTTPS (e.g. api-origin.energia.com.br). Empty = HTTP between CloudFront and the ALB (not recommended)."
  type        = string
  default     = ""
}

variable "ses_domain" {
  description = "Newsletter sender domain verified in SES. Empty = SES is not configured."
  type        = string
  default     = ""
}

variable "cognito_domain_prefix" {
  description = "Hosted UI domain prefix (globally unique in the region)."
  type        = string
}

variable "web_callback_urls" {
  description = "Auth.js callback URLs, e.g. [\"https://energia.com.br/api/auth/callback/cognito\"]."
  type        = list(string)
}

variable "web_logout_urls" {
  description = "Allowed post-logout URLs."
  type        = list(string)
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_name" {
  type    = string
  default = "energia"
}

variable "database_url_scheme" {
  description = "SQLAlchemy scheme for DATABASE_URL (must match the driver used by energia-api)."
  type        = string
  default     = "postgresql+psycopg"
}

variable "api_image_tag" {
  description = "energia-api image tag used by the service and the migration task. CI moves \"latest\"; pin a SHA here to roll back."
  type        = string
  default     = "latest"
}

variable "api_cpu" {
  type    = number
  default = 256
}

variable "api_memory" {
  type    = number
  default = 512
}

variable "api_cpu_architecture" {
  type    = string
  default = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.api_cpu_architecture)
    error_message = "api_cpu_architecture must be X86_64 or ARM64."
  }
}

variable "api_desired_count" {
  type    = number
  default = 1
}

variable "api_extra_environment" {
  description = "Extra plain environment variables for the API container (e.g. the newsletter sender address)."
  type        = map(string)
  default     = {}
}

variable "airflow_instance_type" {
  type    = string
  default = "t3.large"
}

variable "airflow_root_volume_size_gb" {
  type    = number
  default = 40
}

variable "alarm_email" {
  description = "E-mail that receives the alarms (confirm the SNS subscription). Empty = no subscription."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "github_owner" {
  description = "GitHub organisation or user owning energia-api, energia-data and energia-infra."
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Set to false if the account already has the token.actions.githubusercontent.com provider."
  type        = bool
  default     = true
}
