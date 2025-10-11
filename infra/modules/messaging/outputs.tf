output "queue_url" {
  value = aws_sqs_queue.processing_queue.url
}

output "queue_arn" {
  value = aws_sqs_queue.processing_queue.arn
}

output "dlq_url" {
  value = aws_sqs_queue.processing_dlq.url
}