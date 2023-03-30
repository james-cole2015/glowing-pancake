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
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eureka_igw.id
  }
  tags = {
    Name = var.public_rt_name
  }
}

resource "aws_security_group" "public_sg" {
  name        = "sg rules for instances"
  description = "Security Group rules for AWS Instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = "0.0.0.0/0"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = "0.0.0.0/0"
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = "0.0.0.0/0"
  }

  tags = {
    Name = "public_sg"
  }
}

resource "aws_security_group" "private_sg" {
  name        = "sg rules for instances"
  description = "Security Group rules for AWS Instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = "0.0.0.0/0"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public_sg"
  }
}

resource "aws_instance" "public_redhat_instance" {
  ami                         = var.instance_ami
  instance_type               = "t2.micro"
  vpc_security_group_ids      = aws_security_group.public_sg.id
  subnet_id                   = aws_subnet.public_sn.id
  associate_public_ip_address = true
   key_name                    = aws_key_pair.public_instance_kp.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install httpd -y
              systemctl start httpd
              systemctl enable httpd
              EOF


  tags = {
    Name = "Public Red Hat Enterprise Linux 9"
  }
}

resource "aws_instance" "private_redhat_instance" {
  ami                         = var.instance_ami
  instance_type               = "t2.micro"
  vpc_security_group_ids      = aws_security_group.public_sg.id
  subnet_id                   = aws_subnet.public_sn.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.private_instance_kp.key_name

  tags = {
    Name = "Private Red Hat Enterprise Linux 9"
  }
}
### Creating Key Pairs

## KEY PAIR FOR PRIVATE INSTANCE && COPY TO LOCAL
resource "aws_key_pair" "private_instance_kp" {
  key_name   = "public_rhel_key"
  public_key = tls_private_key.rsa_public_key_1.public_key_openssh
}

resource "tls_private_key" "rsa_public_key_1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "created_keypair_to_local" {
  content         = tls_private_key.rsa_public_key_1.private_key_openssh
  file_permission = "400"
  filename        = "${module.key_pair.key_pair_name}.pem"
}

## KEY PAIR FOR PUBLIC INSTANCE && COPY TO LOCAL

resource "tls_private_key" "rsa_private_key_1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "public_instance_kp" {
  key_name   = "public_rhel_key"
  public_key = tls_private_key.rsa_private_key_1.public_key_openssh
}

resource "local_file" "created_keypair_to_local" {
  content         = tls_private_key.rsa_private_key_1.private_key_openssh
  file_permission = "400"
  filename        = "${module.key_pair.key_pair_name}.pem"
}