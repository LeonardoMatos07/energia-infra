output "role_arns" {
  description = "Role ARN per purpose (api, data, infra_plan, infra_apply)."
  value       = { for key, role in aws_iam_role.this : key => role.arn }
}
