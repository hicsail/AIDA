# RDS Password
resource "random_password" "aida_db_password" {
  length      = 20
  special     = true
  min_special = 0
}

resource "aws_secretsmanager_secret" "aida_db_password_secret" {
  name = "aida-db-password4"
}

resource "aws_secretsmanager_secret_version" "db_password_secret_value" {
  secret_id = aws_secretsmanager_secret.aida_db_password_secret.id
  secret_string = jsonencode({
    password = random_password.aida_db_password.result
  })
}

# RDS Subnet Group
resource "aws_db_subnet_group" "aida_db_subnet_group" {
  name        = "aida-db-subnet-group"
  description = "Subnet group for AIDA API RDS Cluster"
  subnet_ids  = var.private_subnet_ids
}

# RDS Security Group
resource "aws_security_group" "aida_rds_sg" {
  name        = "aida-rds-sg"
  description = "Security Group for AIDA API RDS Cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
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

resource "aws_rds_cluster" "aida_db" {
  enabled_cloudwatch_logs_exports = ["postgresql"]
  engine_mode                     = "provisioned"
  deletion_protection             = true
  cluster_identifier              = "aida-postgres"
  engine                          = "aurora-postgresql"
  apply_immediately               = true
  skip_final_snapshot             = true
  enable_http_endpoint            = true
  engine_version                  = "16.4"
  database_name                   = "litellm"
  master_username                 = "aida"
  master_password                 = jsondecode(aws_secretsmanager_secret_version.db_password_secret_value.secret_string).password
  db_subnet_group_name            = aws_db_subnet_group.aida_db_subnet_group.name
  vpc_security_group_ids          = [aws_security_group.aida_rds_sg.id]
  serverlessv2_scaling_configuration {
    max_capacity = 1
    min_capacity = 0.5
  }
  allow_major_version_upgrade = true
  storage_encrypted           = true
}

resource "aws_rds_cluster_instance" "writer" {
  count = 1
  # Setting promotion tier to 0 makes the instance eligible to become a writer.
  promotion_tier       = 0
  cluster_identifier   = aws_rds_cluster.aida_db.cluster_identifier
  identifier_prefix    = "${aws_rds_cluster.aida_db.cluster_identifier}-"
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.aida_db.engine
  engine_version       = aws_rds_cluster.aida_db.engine_version
  db_subnet_group_name = aws_db_subnet_group.aida_db_subnet_group.name
  depends_on           = [aws_rds_cluster.aida_db]
}

resource "aws_rds_cluster_instance" "reader" {
  count = 1
  # Any promotion tier above 1 is a reader, and cannot become a writer.
  # If the cluster comes up with a reader instance as the writer, initiate a failover.
  promotion_tier       = 2
  cluster_identifier   = aws_rds_cluster.aida_db.cluster_identifier
  identifier_prefix    = "${aws_rds_cluster.aida_db.cluster_identifier}-"
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.aida_db.engine
  engine_version       = aws_rds_cluster.aida_db.engine_version
  db_subnet_group_name = aws_db_subnet_group.aida_db_subnet_group.name
  depends_on           = [aws_rds_cluster.aida_db]
}
