output "identity_arn" {
  value = aws_sesv2_email_identity.this.arn
}

output "dkim_dns_records" {
  description = "CNAME records to create at the DNS provider to verify the domain (Easy DKIM)."
  value = [
    for token in aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens : {
      type  = "CNAME"
      name  = "${token}._domainkey.${var.domain}"
      value = "${token}.dkim.amazonses.com"
    }
  ]
}
