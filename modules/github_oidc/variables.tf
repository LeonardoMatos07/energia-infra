variable "name_prefix" {
  type = string
}

variable "secrets_prefix" {
  type = string
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider (false if the account already has one)."
  type        = bool
  default     = true
}

variable "github_owner" {
  description = "GitHub organisation or user that owns the repositories."
  type        = string
}

variable "api_repository" {
  type    = string
  default = "spillway-api"
}

variable "data_repository" {
  type    = string
  default = "spillway-data"
}

variable "infra_repository" {
  type    = string
  default = "spillway-infra"
}

variable "production_environment" {
  description = "GitHub environment with required reviewers."
  type        = string
  default     = "production"
}

variable "api_ecr_repository_arn" {
  type = string
}

variable "data_ecr_repository_arn" {
  type = string
}

variable "ecs_cluster_arn" {
  type = string
}

variable "ecs_service_arn" {
  type = string
}

variable "migration_task_family" {
  type = string
}

variable "ecs_task_role_arns" {
  description = "Execution and task roles that run-task may pass."
  type        = list(string)
}

variable "api_log_group_arn" {
  type = string
}

variable "airflow_instance_arn" {
  type = string
}

variable "state_bucket_arn" {
  type = string
}
