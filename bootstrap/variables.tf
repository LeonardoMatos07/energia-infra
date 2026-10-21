variable "region" {
  description = "AWS region of the state bucket."
  type        = string
  default     = "sa-east-1"
}

variable "project" {
  description = "Project name, used in resource names and tags."
  type        = string
  default     = "energia"
}

variable "state_bucket_name" {
  description = "Explicit state bucket name. Empty = <project>-tfstate-<account_id>."
  type        = string
  default     = ""
}
