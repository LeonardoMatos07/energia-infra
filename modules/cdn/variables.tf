variable "name_prefix" {
  type = string
}

variable "api_domain" {
  description = "Public API hostname served by CloudFront (e.g. api.energia.com.br). Empty = *.cloudfront.net."
  type        = string
  default     = ""
}

variable "https_origin" {
  description = "Whether the ALB origin is reached over HTTPS at var.origin_domain."
  type        = bool
}

variable "origin_domain" {
  description = "ALB origin hostname (used when https_origin = true)."
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "ALB DNS name (used when https_origin = false)."
  type        = string
}

variable "origin_verify_header_value" {
  description = "Secret sent to the ALB in X-Origin-Verify."
  type        = string
  sensitive   = true
}

variable "price_class" {
  type    = string
  default = "PriceClass_All"
}
