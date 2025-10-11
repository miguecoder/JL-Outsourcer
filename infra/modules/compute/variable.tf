variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "raw_bucket_name" {
  type = string
}

variable "raw_bucket_arn" {
  type = string
}

variable "queue_url" {
  type = string
}

variable "queue_arn" {
  type = string
}

variable "ingestion_lambda_zip" {
  type = string
}

variable "processing_lambda_zip" {
  type = string
}

variable "curated_table_name" {
  type = string
}

variable "curated_table_arn" {
  type = string
}