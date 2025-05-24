terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Generate SSH key pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Save private key for SSH access
resource "local_file" "private_key" {
  content          = tls_private_key.ssh.private_key_pem
  filename         = "${path.module}/parking-lot-key.pem"
  file_permission  = "0400"
}

# Register EC2 key pair in AWS using the public key
resource "aws_key_pair" "key" {
  key_name   = "parking-lot-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# IAM Role for EC2 instance
resource "aws_iam_role" "api_role" {
  name               = "parking-lot-api-role"
  assume_role_policy = file("${path.module}/assume-role-policy.json")
}

# Attach DynamoDB Full Access to the IAM role
resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  role       = aws_iam_role.api_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Instance profile to bind IAM role to EC2
resource "aws_iam_instance_profile" "api_profile" {
  name = "parking-lot-api-profile"
  role = aws_iam_role.api_role.name
}

# DynamoDB Table
resource "aws_dynamodb_table" "tickets" {
  name         = "ParkingTickets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ticketId"

  attribute {
    name = "ticketId"
    type = "S"
  }
}

# Security Group for SSH and HTTP access
resource "aws_security_group" "sg" {
  name        = "parking-lot-sg"
  description = "Allow SSH and HTTP access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "api" {
  ami                    = "ami-0953476d60561c955"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile   = aws_iam_instance_profile.api_profile.name
  user_data              = file("${path.module}/user_data.sh")

  tags = {
    Name = "parking-lot-api-instance"
  }
}
