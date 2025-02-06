variable "vpc_id" {
  description = "ID of the VPC where ECS resources will be deployed"
  type = string
}

variable "private_subnet_ids" {
  description = "List of subnet IDs for ECS services"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ECS services"
  type        = list(string)
}

variable database_url {
  description = "Database URL"
  type        = string
}

variable redis_host {
  description = "Redis Host"
  type        = string
}