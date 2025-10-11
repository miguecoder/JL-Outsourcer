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