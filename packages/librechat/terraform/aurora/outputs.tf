output "database_url" {
  value = "postgresql://beacon:${jsondecode(aws_secretsmanager_secret_version.db_password_secret_value.secret_string).password}@${aws_rds_cluster.beacon_api_db.endpoint}:5432/beacon"
  sensitive = true
}