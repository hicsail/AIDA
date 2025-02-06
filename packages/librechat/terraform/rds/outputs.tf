output "database_litellm" {
  value = "postgresql://aida:${jsondecode(aws_secretsmanager_secret_version.db_password_secret_value.secret_string).password}@${aws_rds_cluster.aida_db.endpoint}:5432/litellm"
  sensitive = true
}

output "database_rag" {
  value = "postgresql://aida:${jsondecode(aws_secretsmanager_secret_version.db_password_secret_value.secret_string).password}@${aws_rds_cluster.aida_db.endpoint}:5432/rag"
  sensitive = true
}
