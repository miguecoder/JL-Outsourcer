# ========================================
# INGESTION LAMBDA
# ========================================

resource "aws_iam_role" "ingestion_lambda" {
  name = "${var.project_name}-ingestion-lambda-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ingestion_lambda" {
  name = "${var.project_name}-ingestion-lambda-policy-${var.environment}"
  role = aws_iam_role.ingestion_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.raw_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = var.queue_arn
      }
    ]
  })
}

resource "aws_lambda_function" "ingestion" {
  filename         = var.ingestion_lambda_zip
  function_name    = "${var.project_name}-ingestion-${var.environment}"
  role            = aws_iam_role.ingestion_lambda.arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256(var.ingestion_lambda_zip)
  runtime         = "nodejs16.x"
  timeout         = 60
  memory_size     = 256

  environment {
    variables = {
      RAW_BUCKET_NAME = var.raw_bucket_name
      QUEUE_URL       = var.queue_url
    }
  }

  tags = {
    Name = "Ingestion Lambda"
  }
}

resource "aws_cloudwatch_event_rule" "ingestion_schedule" {
  name                = "${var.project_name}-ingestion-schedule-${var.environment}"
  description         = "Trigger ingestion every 30 minutes"
  schedule_expression = "rate(30 minutes)"
}

resource "aws_cloudwatch_event_target" "ingestion_lambda" {
  rule      = aws_cloudwatch_event_rule.ingestion_schedule.name
  target_id = "IngestionLambda"
  arn       = aws_lambda_function.ingestion.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ingestion_schedule.arn
}

# ========================================
# PROCESSING LAMBDA
# ========================================

resource "aws_iam_role" "processing_lambda" {
  name = "${var.project_name}-processing-lambda-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "processing_lambda" {
  name = "${var.project_name}-processing-lambda-policy-${var.environment}"
  role = aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.raw_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ]
        Resource = var.curated_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.queue_arn
      }
    ]
  })
}

resource "aws_lambda_function" "processing" {
  filename         = var.processing_lambda_zip
  function_name    = "${var.project_name}-processing-${var.environment}"
  role            = aws_iam_role.processing_lambda.arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256(var.processing_lambda_zip)
  runtime         = "nodejs16.x"
  timeout         = 60
  memory_size     = 256

  environment {
    variables = {
      CURATED_TABLE_NAME = var.curated_table_name
    }
  }

  tags = {
    Name = "Processing Lambda"
  }
}

resource "aws_lambda_event_source_mapping" "processing_sqs" {
  event_source_arn = var.queue_arn
  function_name    = aws_lambda_function.processing.arn
  batch_size       = 10
}
