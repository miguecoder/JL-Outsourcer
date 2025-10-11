resource "aws_sqs_queue" "processing_queue" {
  name                       = "${var.project_name}-processing-${var.environment}"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 10

  tags = {
    Name = "Processing Queue"
  }
}

resource "aws_sqs_queue" "processing_dlq" {
  name = "${var.project_name}-processing-dlq-${var.environment}"

  tags = {
    Name = "Processing DLQ"
  }
}

resource "aws_sqs_queue_redrive_policy" "processing_queue" {
  queue_url = aws_sqs_queue.processing_queue.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.processing_dlq.arn
    maxReceiveCount     = 3
  })
}