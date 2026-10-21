variable "name_prefix" {
  type = string
}

variable "log_prefix" {
  description = "Log group path prefix (e.g. energia/prod)."
  type        = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "alarm_email" {
  description = "E-mail subscribed to the alert topic. Empty = no subscription."
  type        = string
  default     = ""
}

variable "metric_namespace" {
  description = "Namespace of the custom metrics."
  type        = string
  default     = "Energia"
}

variable "alb_arn_suffix" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "db_instance_identifier" {
  type = string
}

variable "airflow_instance_id" {
  type = string
}

variable "alb_5xx_threshold_percent" {
  type    = number
  default = 5
}

variable "rds_free_storage_threshold_gb" {
  type    = number
  default = 2
}

variable "airflow_failure_pattern" {
  description = "CloudWatch Logs filter pattern that matches a failed Airflow task."
  type        = string
  default     = "?\"Task failed with exception\" ?\"Marking task as FAILED\""
}
