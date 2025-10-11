output "ingestion_lambda_arn" {
  value = aws_lambda_function.ingestion.arn
}

output "ingestion_lambda_name" {
  value = aws_lambda_function.ingestion.function_name
}

output "processing_lambda_arn" {
  value = aws_lambda_function.processing.arn
}

output "processing_lambda_name" {
  value = aws_lambda_function.processing.function_name
}