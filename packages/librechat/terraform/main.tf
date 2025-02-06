terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.54.1"
    }
  }

  backend "s3" {
    bucket         = "beacon-api-terraform-state"
    key            = "beacon-api/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      "Project" = "Beacon API"
    }
  }
}

module "ecs" {
  source = "./ecs"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids = module.vpc.public_subnet_ids
  database_url = module.rds.database_url
  redis_host = module.redis.redis_host
}

module "rds" {
  source = "./rds"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "redis" {
  source = "./redis"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "vpc" {
  source = "./vpc"
}