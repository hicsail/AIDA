output "redis_host" {
  value = aws_elasticache_cluster.beacon_api_redis.cache_nodes[0].address
}