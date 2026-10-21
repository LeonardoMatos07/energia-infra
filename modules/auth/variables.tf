variable "name_prefix" {
  type = string
}

variable "secrets_prefix" {
  type = string
}

variable "domain_prefix" {
  description = "Cognito hosted UI domain prefix (<prefix>.auth.<region>.amazoncognito.com). Must be globally unique."
  type        = string
}

variable "web_callback_urls" {
  description = "Auth.js callback URLs (e.g. https://<portal>/api/auth/callback/cognito)."
  type        = list(string)
}

variable "web_logout_urls" {
  description = "URLs allowed after logout."
  type        = list(string)
}
