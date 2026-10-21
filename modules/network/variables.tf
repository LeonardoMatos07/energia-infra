variable "name_prefix" {
  description = "Prefix for resource names (e.g. energia-prod)."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR block (a /16 is expected; subnets are /24)."
  type        = string
  default     = "10.20.0.0/16"
}
