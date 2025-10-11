# CloudWatch Dashboard for TWL Pipeline

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # Lambda Invocations
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Ingestion" }, { dimensions = { FunctionName = var.ingestion_lambda_name } }],
            ["...", { dimensions = { FunctionName = var.processing_lambda_name } }],
            ["...", { dimensions = { FunctionName = var.api_lambda_name } }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Invocations"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
      
      # Lambda Errors
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", { stat = "Sum", label = "Ingestion Errors" }, { dimensions = { FunctionName = var.ingestion_lambda_name } }],
            ["...", { dimensions = { FunctionName = var.processing_lambda_name }, label = "Processing Errors" }],
            ["...", { dimensions = { FunctionName = var.api_lambda_name }, label = "API Errors" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Errors"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },
      
      # Lambda Duration
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", { stat = "Average", label = "Ingestion" }, { dimensions = { FunctionName = var.ingestion_lambda_name } }],
            ["...", { dimensions = { FunctionName = var.processing_lambda_name } }],
            ["...", { dimensions = { FunctionName = var.api_lambda_name } }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Lambda Duration (ms)"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 6
      },
      
      # SQS Messages
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", { label = "Messages Sent" }, { dimensions = { QueueName = var.queue_name } }],
            [".", "NumberOfMessagesReceived", { label = "Messages Received" }, { dimensions = { QueueName = var.queue_name } }],
            [".", "ApproximateNumberOfMessagesVisible", { label = "Messages Visible" }, { dimensions = { QueueName = var.queue_name } }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "SQS Queue Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 6
      },
      
      # DynamoDB Operations
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum", label = "Read Units" }, { dimensions = { TableName = var.dynamodb_table_name } }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum", label = "Write Units" }, { dimensions = { TableName = var.dynamodb_table_name } }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "DynamoDB Capacity Units"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 12
      },
      
      # API Gateway Requests
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", { stat = "Sum", label = "Requests" }, { dimensions = { ApiId = var.api_gateway_id } }],
            [".", "4XXError", { stat = "Sum", label = "4XX Errors" }, { dimensions = { ApiId = var.api_gateway_id } }],
            [".", "5XXError", { stat = "Sum", label = "5XX Errors" }, { dimensions = { ApiId = var.api_gateway_id } }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "API Gateway Requests & Errors"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 12
      },
      
      # Lambda Throttles
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Throttles", { stat = "Sum" }, { dimensions = { FunctionName = var.ingestion_lambda_name } }],
            ["...", { dimensions = { FunctionName = var.processing_lambda_name } }],
            ["...", { dimensions = { FunctionName = var.api_lambda_name } }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Throttles"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 18
      },
      
      # API Latency
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", { stat = "Average", label = "Average" }, { dimensions = { ApiId = var.api_gateway_id } }],
            ["...", { stat = "p99", label = "p99" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "API Gateway Latency (ms)"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 18
      }
    ]
  })
}

# CloudWatch Alarms

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Lambda error rate is too high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.ingestion_lambda_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-dlq-messages-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Messages in DLQ indicate processing failures"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.dlq_name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "${var.project_name}-api-5xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "API Gateway 5XX error rate is too high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_gateway_id
  }
}

