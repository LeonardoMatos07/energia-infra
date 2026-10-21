variable "name_prefix" {
  type = string
}

variable "secrets_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet for the instance."
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}

variable "root_volume_size_gb" {
  type    = number
  default = 40
}

variable "compose_version" {
  description = "Docker Compose plugin release installed on the host."
  type        = string
  default     = "v5.6.0"
}

variable "lake_bucket_name" {
  type = string
}

variable "lake_bucket_arn" {
  type = string
}

variable "ecr_repository_arn" {
  description = "ARN of the energia-data ECR repository."
  type        = string
}

variable "warehouse_secret_arn" {
  type = string
}

variable "machine_client_secret_arn" {
  type = string
}

variable "api_url" {
  description = "Public API base URL (API_URL)."
  type        = string
}

variable "log_group_name" {
  type = string
}
