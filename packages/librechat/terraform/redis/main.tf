resource "aws_security_group" "beacon_api_redis_sg" {
  name        = "beacon-api-redis-sg"
  description = "Security Group for Beacon API Redis"
  vpc_id = var.vpc_id


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
resource "aws_elasticache_subnet_group" "beacon_api_redis_subnet_group" {
  name        = "beacon-api-redis-subnet-group"
  description = "Subnet group for Beacon API Redis Cluster"
  subnet_ids  = var.private_subnet_ids
}

resource "aws_elasticache_cluster" "beacon_api_redis" {
  cluster_id           = "beacon-api-redis"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  engine_version       = "6.x"
  security_group_ids = [aws_security_group.beacon_api_redis_sg.id]
  subnet_group_name = aws_elasticache_subnet_group.beacon_api_redis_subnet_group.name
}
