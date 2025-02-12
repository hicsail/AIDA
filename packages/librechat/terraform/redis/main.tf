resource "aws_security_group" "aida_redis_sg" {
  name        = "aida-redis-sg"
  description = "Security Group for AIDA Redis"
  vpc_id      = var.vpc_id


  ingress {
    from_port   = 6379
    to_port     = 6379
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

# Redis Subnet Group
resource "aws_elasticache_subnet_group" "aida_redis_subnet_group" {
  name        = "aida-redis-subnet-group"
  description = "Subnet group for AIDA Redis Cluster"
  subnet_ids  = var.private_subnet_ids
}

resource "aws_elasticache_cluster" "aida_redis" {
  cluster_id         = "aida-redis"
  engine             = "redis"
  node_type          = "cache.t2.micro"
  num_cache_nodes    = 1
  engine_version     = "6.x"
  security_group_ids = [aws_security_group.aida_redis_sg.id]
  subnet_group_name  = aws_elasticache_subnet_group.aida_redis_subnet_group.name
}
