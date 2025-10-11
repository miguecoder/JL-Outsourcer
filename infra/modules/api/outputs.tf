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

