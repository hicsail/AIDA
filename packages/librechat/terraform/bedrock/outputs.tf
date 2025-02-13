output "bedrock_access_id" {
  value     = jsondecode(aws_secretsmanager_secret_version.aida_bedrock_secret_value.secret_string).access
  sensitive = true
}

output "bedrock_access_secret" {
  value     = jsondecode(aws_secretsmanager_secret_version.aida_bedrock_secret_value.secret_string).secret
  sensitive = true
}
