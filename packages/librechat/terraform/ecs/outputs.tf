output "execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

output "ecs_log_group" {
  value = aws_cloudwatch_log_group.ecs_log_group.name
}

output "cluster_id" {
  value = aws_ecs_cluster.aida_cluster.id
}
