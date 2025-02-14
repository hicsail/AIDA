variable "vpc_id" {
  description = "ID of the VPC where ECS resources will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of subnet IDs for ECS services"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ECS services"
  type        = list(string)
}

variable "database_url" {
  description = "Database URL"
  type        = string
}

variable "execution_role_arn" {
  description = "Execution IAM role ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "Task IAM role ARN"
  type        = string
}

variable "ecs_log_group" {
  description = "Cloudwatch group name"
  type        = string
}

variable "cluster_id" {
  description = "Fargate Cluster ID"
  type        = string
}

variable "litellm_key" {
  description = "LiteLLM Access Key"
  type        = string
}

variable "rag_dns" {
  description = "DNS of RAG Endpoint"
  type        = string
}
