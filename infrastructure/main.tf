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
# Subnets
# -----------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
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
# App (EC2) SG
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow HTTP, app port 5000, and SSH"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS SG
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow access from app servers only"

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# -----------------------
# IAM Role + Trust Policy
# -----------------------

resource "aws_iam_role" "ec2_role" {
  name = var.ec2_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
# -----------------------
# Policy za S3
# -----------------------


# -----------------------
# Attach policy to role
# -----------------------
resource "aws_iam_role_policy_attachment" "attach_s3" {
  role = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# -----------------------
# Create instance profile
# -----------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = var.ec2_instance_profile_name
  role = aws_iam_role.ec2_role.name
}


# -----------------------
# EC2 Instance
# -----------------------
resource "aws_instance" "app_server" {
  ami                    = var.app_ami
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name #Attach profile to EC2 instance
  key_name = var.key_name
  associate_public_ip_address = true
  tags = { Name = "app-server" }


  #user_data = <<-EOF
  ##!/bin/bash
  #sudo apt update
  #sudo apt install -y python3-pip
  #nohup python3 /home/ubuntu/app.py --port 5000 &
  #EOF
      
}

# -----------------------
# RDS Subnet Group
# -----------------------
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "main-subnet-group"
  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]
  tags = { Name = "main-subnet-group" }
}

# -----------------------
# RDS PostgreSQL
# -----------------------
resource "aws_db_instance" "mydb" {
  allocated_storage      = var.db_allocated_storage
  engine                 = var.db_engine
  engine_version         = var.engine_version
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  port                   = var.db_port
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az               = true
  skip_final_snapshot    = true
}
# -----------------------
# SNS Topic 
# -----------------------
resource "aws_sns_topic" "alerts" {
  name = "app-alerts"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email 
}

# -----------------------
# CloudWatch Alarm za EC2 CPU
# -----------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = var.cloudwatch_alarm_name
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.cpu_alarm_period
  statistic           = "Average"
  threshold           = var.cpu_threshold

  dimensions = {
    InstanceId = aws_instance.app_server.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}