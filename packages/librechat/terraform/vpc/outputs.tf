output "vpc_id" {
  value = aws_vpc.beacon_api_vpc.id
}

output "private_subnet_ids" {
  value = aws_subnet.beacon_api_private_subnet[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.beacon_api_public_subnet[*].id
}