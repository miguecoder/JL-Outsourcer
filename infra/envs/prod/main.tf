module "storage" {
  source = "../../modules/storage"

  project_name = var.project_name
  environment  = var.environment
}

module "messaging" {
  source = "../../modules/messaging"

  project_name = var.project_name
  environment  = var.environment
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment
  
  raw_bucket_name = module.storage.raw_bucket_name
  raw_bucket_arn  = module.storage.raw_bucket_arn
  queue_url       = module.messaging.queue_url
  queue_arn       = module.messaging.queue_arn
  
  curated_table_name = module.storage.curated_table_name
  curated_table_arn  = module.storage.curated_table_arn
  
  ingestion_lambda_zip   = "${path.root}/../../../lambda-ingestion.zip"
  processing_lambda_zip  = "${path.root}/../../../lambda-processing.zip"
}

module "api" {
  source = "../../modules/api"

  project_name = var.project_name
  environment  = var.environment
  
  curated_table_name = module.storage.curated_table_name
  curated_table_arn  = module.storage.curated_table_arn
  
  api_lambda_zip = "${path.root}/../../../lambda-api.zip"
}

module "observability" {
  source = "../../modules/observability"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = "us-east-1"
  
  ingestion_lambda_name  = module.compute.ingestion_lambda_name
  processing_lambda_name = module.compute.processing_lambda_name
  api_lambda_name        = module.api.api_lambda_name
  
  queue_name           = module.messaging.queue_name
  dlq_name             = module.messaging.dlq_name
  dynamodb_table_name  = module.storage.curated_table_name
  api_gateway_id       = module.api.api_gateway_id
}

