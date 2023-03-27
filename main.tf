### creating the vpc with public and private subnets

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "public_sn" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_sn_cidr

  tags = {
    Name = var.public_sn_name
  }
}

resource "aws_subnet" "private_sn" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_sn_cidr

  tags = {
    Name = var.private_sn_name
  }
}

## creating internet gateway and attaching to public subnet

resource "aws_internet_gateway" "eureka_igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.igw_name
  }
}


## creating NAT Gateway for private subnet connectivity

resource "aws_eip" "eip_nat_gw" {
  depends_on = [aws_internet_gateway.eureka_igw]
}

resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.eip_nat_gw.id
  subnet_id     = aws_subnet.public_sn.id

  tags = {
    Name = var.nat_gw_name
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.eureka_igw]
}

### private route table to establish internet connectivity

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = var.private_sn_cidr
    nat_gateway_id = aws_nat_gateway.example.id
  }
  tags = {
    Name = var.private_rt_name
  }
}


resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = var.public_sn_cidr
    nat_gateway_id = aws_internet_gateway.eureka_igw.id
  }
  tags = {
    Name = var.public_rt_name
  }
}
