output "api_url" {
  description = "API Gateway endpoint URL"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/${aws_apigatewayv2_stage.main.name}"
}

output "api_lambda_name" {
  description = "API Lambda function name"
  value       = aws_lambda_function.api.function_name
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.main.id
}

output "api_key_parameter" {
  description = "SSM Parameter name for API Key"
  value       = aws_ssm_parameter.api_key.name
  sensitive   = true
}

output "api_key_value" {
  description = "API Key value (use for frontend configuration)"
  value       = aws_ssm_parameter.api_key.value
  sensitive   = true
}

