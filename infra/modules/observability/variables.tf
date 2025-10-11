variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ingestion_lambda_name" {
  type = string
}

variable "processing_lambda_name" {
  type = string
}

variable "api_lambda_name" {
  type = string
}

variable "queue_name" {
  type = string
}

variable "dlq_name" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "api_gateway_id" {
  type = string
}

