# DocumentDB Password
resource "random_password" "aida_documentdb_password" {
  length      = 20
  special     = true
  min_special = 0
}

resource "aws_secretsmanager_secret" "aida_documentdb_password_secret" {
  name = "aida-documentdb-password"
}

resource "aws_secretsmanager_secret_version" "documentdb_password_secret_value" {
  secret_id = aws_secretsmanager_secret.aida_documentdb_password_secret.id
  secret_string = jsonencode({
    password = random_password.aida_documentdb_password.result
  })
}

# DocumentDB Subnet Group
resource "aws_docdb_subnet_group" "aida_documentdb_subnet_group" {
  name        = "aida-documentdb-subnet-group"
  description = "Subnet group for AIDA API DocumentDB Cluster"
  subnet_ids  = var.private_subnet_ids
}

# AIDA Security Group
resource "aws_security_group" "aida_documentdb_sg" {
  name        = "aida-documentdb-sg"
  description = "Security Group for AIDA API DocumentDB Cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_docdb_cluster" "aida_documentdb" {
  enabled_cloudwatch_logs_exports = ["audit"]
  deletion_protection             = true
  cluster_identifier              = "aida-documentdb"
  engine                          = "docdb"
  apply_immediately               = true
  skip_final_snapshot             = true
  engine_version                  = "5.0.0"
  master_username                 = "aida"
  master_password                 = jsondecode(aws_secretsmanager_secret_version.documentdb_password_secret_value.secret_string).password
  db_subnet_group_name            = aws_docdb_subnet_group.aida_documentdb_subnet_group.name
  vpc_security_group_ids          = [aws_security_group.aida_documentdb_sg.id]
  allow_major_version_upgrade = true
  storage_encrypted           = true
}

resource "aws_docdb_cluster_instance" "aida_documentdb" {
  count = 1
  # Setting promotion tier to 0 makes the instance eligible to become a writer.
  promotion_tier       = 0
  cluster_identifier   = aws_docdb_cluster.aida_documentdb.cluster_identifier
  identifier_prefix    = "${aws_docdb_cluster.aida_documentdb.cluster_identifier}-"
  instance_class       = "db.t3.medium"
  engine               = aws_docdb_cluster.aida_documentdb.engine
  depends_on           = [aws_docdb_cluster.aida_documentdb]
}
