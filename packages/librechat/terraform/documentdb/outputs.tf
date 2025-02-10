# output "database_librechat" {
# value = "mongodb://aida:${jsondecode(aws_secretsmanager_secret_version.documentdb_password_secret_value.secret_string).password}@${aws_docdb_cluster.aida_documentdb.endpoint}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
#   sensitive = true
# }
#

output "database_librechat" {
  value = "mongodb://aida:${jsondecode(aws_secretsmanager_secret_version.documentdb_password_secret_value.secret_string).password}@aida-documentdb-20250207200016537900000001.cyimouge4gmi.us-east-1.docdb.amazonaws.com:27017/?retryWrites=false"
  sensitive = true
}
