terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.54.1"
    }
  }

  backend "s3" {
    bucket  = "aida-terraform-state"
    key     = "aida/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      "Project" = "BU - AIDA"
    }
  }
}

module "ecs" {
  source = "./ecs"
}

module "rds" {
  source             = "./rds"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "redis" {
  source             = "./redis"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "litellm" {
  source             = "./litellm"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  database_url       = module.rds.database_litellm
  execution_role_arn = module.ecs.execution_role_arn
  ecs_task_role_arn  = module.ecs.ecs_task_role_arn
  ecs_log_group      = module.ecs.ecs_log_group
  cluster_id         = module.ecs.cluster_id
}

module "documentdb" {
  source             = "./documentdb/"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "librechat" {
  source             = "./librechat/"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  database_url       = module.documentdb.database_librechat
  execution_role_arn = module.ecs.execution_role_arn
  ecs_task_role_arn  = module.ecs.ecs_task_role_arn
  ecs_log_group      = module.ecs.ecs_log_group
  cluster_id         = module.ecs.cluster_id
  litellm_key        = module.litellm.litellm_key
}

module "vpc" {
  source = "./vpc"
}
