output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "api_url" {
  description = "Public base URL of the API (API_URL)."
  value       = local.custom_domain ? "https://${var.api_domain}" : "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "certificate_validation_records" {
  description = "DNS records that validate the CloudFront certificate."
  value = local.custom_domain ? [
    for o in aws_acm_certificate.api[0].domain_validation_options : {
      type  = o.resource_record_type
      name  = o.resource_record_name
      value = o.resource_record_value
    }
  ] : []
}
