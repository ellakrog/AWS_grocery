provider "aws" {
  region = var.aws_region
}

# -----------------------
# VPC
# -----------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "main-vpc" }
}

# -----------------------
# Subneti
# -----------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = { Name = "public-subnet" }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet1_cidr
  availability_zone = "${var.aws_region}a"
  tags = { Name = "private-subnet-1" }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet2_cidr
  availability_zone = "${var.aws_region}b"
  tags = { Name = "private-subnet-2" }
}

# -----------------------
# Internet Gateway + Route Table
# -----------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------
# Security Groups
# -----------------------
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow HTTP, app port 5000, SSH, and PostgreSQL"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # EC2 može pristupiti RDS-u unutar VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------
# EC2 Instance (Public)
# -----------------------
resource "aws_instance" "app_server" {
  ami           = "ami-0683ee28af6610487"
  instance_type = var.app_instance_type
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = { Name = "app-server" }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install -y python3-pip
              nohup python3 /home/ubuntu/app.py --port 5000 &
              EOF
}

# -----------------------
# RDS PostgreSQL (Private, Multi-AZ)
# -----------------------
resource "aws_db_subnet_group" "main" {
  name       = "main-subnet-group"
  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]
  tags = { Name = "main-subnet-group" }
}

resource "aws_db_instance" "mydb" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = null
  instance_class         = var.db_instance_class
  db_name                = "mydb"
  username               = "dbadmin"
  password               = var.db_password
  port                   = 5432
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  multi_az               = true        # omogućava failover
  skip_final_snapshot    = true
}

# -----------------------
# S3 Bucket for Avatars
# -----------------------

resource "aws_s3_bucket" "avatars" {
  bucket = "grocerymate-avatars"

  tags = {
    Name        = "grocerymate-avatars"
    Environment = "Dev"
  }
}