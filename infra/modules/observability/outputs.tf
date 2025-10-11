output "dashboard_name" {
  description = "CloudWatch Dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "alarm_arns" {
  description = "CloudWatch Alarm ARNs"
  value = {
    lambda_errors = aws_cloudwatch_metric_alarm.lambda_errors.arn
    dlq_messages  = aws_cloudwatch_metric_alarm.dlq_messages.arn
    api_errors    = aws_cloudwatch_metric_alarm.api_errors.arn
  }
}

