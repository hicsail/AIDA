output "bedrock_access_id" {
  value     = jsondecode(aws_secretsmanager_secret_version.secret_string).access
  sensitive = true
}

output "bedrock_access_secret" {
  value     = jsondecode(aws_secretsmanager_secret_version.secret_string).secret
  sensitive = true
}
