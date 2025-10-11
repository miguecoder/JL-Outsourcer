output "raw_bucket_name" {
  value = aws_s3_bucket.raw_data.id
}

output "raw_bucket_arn" {
  value = aws_s3_bucket.raw_data.arn
}

output "curated_table_name" {
  value = aws_dynamodb_table.curated_data.name
}

output "curated_table_arn" {
  value = aws_dynamodb_table.curated_data.arn
}