variable "repository_names" {
  type    = list(string)
  default = ["energia-api", "energia-data"]
}

variable "keep_last_images" {
  type    = number
  default = 20
}
