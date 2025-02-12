output "redis_host" {
  value = aws_elasticache_cluster.aida_redis.cache_nodes[0].address
}
