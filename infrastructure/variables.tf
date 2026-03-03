variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string
  default     = "10.0.3.0/24"
}

variable "my_ip" {
  description = "Your public IP for SSH access"
  type        = string
}
variable "ec2_role_name" {
  type    = string
  default = "grocerymate-ec2-role"
}
variable "s3_policy_name" {
  type    = string
  default = "grocerymate-s3-policy"
}
variable "ec2_instance_profile_name" {
  type    = string
  default = "grocerymate-ec2-profile"
}
variable "app_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
variable "app_ami" {
  description = "AMI ID for the EC2 application server"
  type        = string
  default     = "ami-0683ee28af6610487" 
}
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "12.22"
}
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "grocerymate_db"
}

variable "db_username" {
  description = "RDS username"
  type        = string
  default     = "grocery_user"
}

variable "db_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "RDS port"
  type        = number
  default     = 5432
}

variable "s3_bucket_name" {
  description = "S3 bucket name for avatars"
  type        = string
  default     = "grocerymate-avatars-ljubica"
}

