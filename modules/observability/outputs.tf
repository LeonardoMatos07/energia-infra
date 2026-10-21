output "api_log_group_name" {
  value = aws_cloudwatch_log_group.api.name
}

output "airflow_log_group_name" {
  value = aws_cloudwatch_log_group.airflow.name
}

output "airflow_log_group_arn" {
  value = aws_cloudwatch_log_group.airflow.arn
}

output "api_log_group_arn" {
  value = aws_cloudwatch_log_group.api.arn
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
