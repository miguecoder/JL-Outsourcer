output "raw_bucket_name" {
  value = module.storage.raw_bucket_name
}

output "curated_table_name" {
  value = module.storage.curated_table_name
}

output "queue_url" {
  value = module.messaging.queue_url
}

output "api_url" {
  description = "API Gateway endpoint URL"
  value       = module.api.api_url
}

output "api_lambda_name" {
  description = "API Lambda function name"
  value       = module.api.api_lambda_name
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = module.observability.dashboard_url
}

output "dashboard_name" {
  description = "CloudWatch Dashboard name"
  value       = module.observability.dashboard_name
}

output "api_key_parameter" {
  description = "SSM Parameter name containing the API Key"
  value       = module.api.api_key_parameter
  sensitive   = true
}

output "api_key" {
  description = "API Key for frontend (use: terraform output -raw api_key)"
  value       = module.api.api_key_value
  sensitive   = true
}