variable "name_prefix" {
  type = string
}

variable "secrets_prefix" {
  description = "Prefix of Secrets Manager names (e.g. energia/prod)."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach PostgreSQL, keyed by a static label."
  type        = map(string)
}

variable "engine_version" {
  description = "PostgreSQL major (or major.minor) version."
  type        = string
  default     = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_name" {
  type    = string
  default = "energia"
}

variable "master_username" {
  type    = string
  default = "energia_admin"
}

variable "allocated_storage_gb" {
  type    = number
  default = 20
}

variable "max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling."
  type        = number
  default     = 100
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "database_url_scheme" {
  description = "SQLAlchemy URL scheme used in the API DATABASE_URL (driver of energia-api)."
  type        = string
  default     = "postgresql+psycopg"
}
