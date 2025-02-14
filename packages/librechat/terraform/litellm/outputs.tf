output "litellm_key" {
  value     = jsondecode(aws_secretsmanager_secret_version.litellm_secret_value.secret_string).key
  sensitive = true
}

output "litellm_dns" {
  value = aws_lb.litellm_alb.dns_name 
}
