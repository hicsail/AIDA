output "litellm_key" {
  value     = jsondecode(aws_secretsmanager_secret_version.litellm_secret_value.secret_string).key
  sensetive = true
}
