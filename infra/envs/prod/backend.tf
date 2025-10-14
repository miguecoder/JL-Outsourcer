terraform {
  backend "s3" {
    bucket         = "twl-terraform-state-miguel-20241010"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "TWL-Pipeline"
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
  }
}

