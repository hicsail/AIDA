resource "aws_vpc" "aida_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "aida_public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.aida_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.aida_vpc.cidr_block, 4, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
}

resource "aws_subnet" "aida_private_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.aida_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.aida_vpc.cidr_block, 4, count.index + 2)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = false
}

resource "aws_internet_gateway" "main_gw" {
  vpc_id = aws_vpc.aida_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.aida_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gw.id
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  count          = length(aws_subnet.aida_public_subnet)
  subnet_id      = aws_subnet.aida_public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat_eip" {
  count  = 2
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = 2
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.aida_public_subnet[count.index].id
}

resource "aws_route_table" "private_rt" {
  count  = 2
  vpc_id = aws_vpc.aida_vpc.id
}

resource "aws_route" "private_nat_route" {
  count                  = 2
  route_table_id         = aws_route_table.private_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway[count.index].id
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = length(aws_subnet.aida_private_subnet)
  subnet_id      = aws_subnet.aida_private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}
