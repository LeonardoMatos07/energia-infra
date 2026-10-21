variable "bucket_name" {
  description = "Globally unique name of the lake bucket."
  type        = string
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent object versions are deleted."
  type        = number
  default     = 90
}

variable "bronze_intelligent_tiering_days" {
  description = "Days after creation to move bronze/ objects to Intelligent-Tiering (0 disables the rule)."
  type        = number
  default     = 30
}
