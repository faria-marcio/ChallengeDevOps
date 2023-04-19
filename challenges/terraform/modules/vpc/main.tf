# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Subnet(s) - Private
resource "aws_subnet" "private" {
  count             = length(var.subnet_private_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.subnet_private_cidr, count.index)
  availability_zone = element(var.azs, count.index)
  tags = {
    Name = var.subnet_private_name[count.index]
  }
}

# Subnet(s) - Public
resource "aws_subnet" "public" {
  count             = length(var.subnet_public_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.subnet_public_cidr, count.index)
  availability_zone = element(var.azs, count.index)
  tags = {
    Name = var.subnet_public_name[count.index]
  }
}

# Elastic IP
resource "aws_eip" "main" {
  vpc = true
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.main.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "${var.project_name}-nat"
  }
}

# Route Table - Attach Internet Gateway 
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = var.cidr_block_all
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

# Route Table - Attach NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = var.cidr_block_all
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = {
    Name = "${var.project_name}-rt-private"
  }
}

# Route Table Association - Public
resource "aws_route_table_association" "public" {
  count          = length(var.subnet_public_cidr)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Route Table Association - Private
resource "aws_route_table_association" "private" {
  count          = length(var.subnet_private_cidr)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

# ACL Network - Public
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public.*.id

  ingress {
    protocol   = -1
    rule_no    = var.rule_no_acl
    action     = "allow"
    cidr_block = var.cidr_block_all
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = var.rule_no_acl
    action     = "allow"
    cidr_block = var.cidr_block_all
    from_port  = 0
    to_port    = 0
  }


  tags = {
    Name = "${var.project_name}-acl-public-access"
  }
}

# ACL Network - Private
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private.*.id

  ingress {
    protocol   = -1
    rule_no    = var.rule_no_acl
    action     = "allow"
    cidr_block = var.cidr_block_all
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = var.rule_no_acl
    action     = "allow"
    cidr_block = var.cidr_block_all
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project_name}-acl-private-access"
  }
}
