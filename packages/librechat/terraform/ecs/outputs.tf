output "execution_role_arn" {
  value = ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  value = ecs_task_role.arn
}

output "ecs_log_group" {
  value = ecs_log_group.name
}

output "cluster_id" {
  value = aida_cluster.id
}
