output "vpc_id" {
  value = aws_vpc.aida_vpc.id
}

output "private_subnet_ids" {
  value = aws_subnet.aida_private_subnet[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.aida_public_subnet[*].id
}
