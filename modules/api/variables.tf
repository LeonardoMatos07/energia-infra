variable "name_prefix" {
  type = string
}

variable "secrets_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "origin_domain" {
  description = "Hostname the ALB is reached at by CloudFront (e.g. api-origin.energia.com.br). Empty = HTTP-only fallback."
  type        = string
  default     = ""
}

variable "image_repository_url" {
  type = string
}

variable "image_tag" {
  description = "Image tag deployed by the service and the migration task."
  type        = string
  default     = "latest"
}

variable "cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "cpu_architecture" {
  description = "X86_64 or ARM64 (must match the image built by CI)."
  type        = string
  default     = "X86_64"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "log_group_name" {
  type = string
}

variable "web_url" {
  description = "Public portal URL (WEB_URL), used by the API to call /api/revalidate."
  type        = string
}

variable "cognito_user_pool_id" {
  type = string
}

variable "cognito_app_client_ids" {
  description = "Client ids accepted by the API (web + machine)."
  type        = list(string)
}

variable "api_database_secret_arn" {
  type = string
}

variable "master_user_secret_arn" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "database_url_scheme" {
  type = string
}

variable "database_url_params" {
  description = "Query string appended to the migration DATABASE_URL."
  type        = string
  default     = "sslmode=require"
}

variable "ses_enabled" {
  description = "Grant the task role permission to send e-mail through SES."
  type        = bool
  default     = false
}

variable "extra_environment" {
  description = "Additional plain environment variables for the API container."
  type        = map(string)
  default     = {}
}
