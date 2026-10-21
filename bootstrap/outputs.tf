output "state_bucket" {
  description = "Name of the remote state bucket."
  value       = aws_s3_bucket.state.id
}

output "backend_hcl" {
  description = "Contents for envs/prod/backend.hcl."
  value       = <<-EOT
    bucket = "${aws_s3_bucket.state.id}"
    key    = "prod/terraform.tfstate"
    region = "${var.region}"
  EOT
}
