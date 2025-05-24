provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "tickets" {
  name           = "ParkingTickets"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ticketId"

  attribute {
    name = "ticketId"
    type = "S"
  }
}

resource "aws_iam_role" "api_role" {
  name = "parking-lot-api-role"
  assume_role_policy = file("assume-role-policy.json")
}

resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  role       = aws_iam_role.api_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_instance_profile" "api_profile" {
  name = "parking-lot-api-profile"
  role = aws_iam_role.api_role.name
}

resource "aws_key_pair" "key" {
  key_name   = "parking-lot-key"
  public_key = file("parking-lot-key.pub")  # create this with `ssh-keygen -y`
}

resource "aws_security_group" "sg" {
  name        = "parking-lot-sg"
  description = "Allow HTTP and SSH"

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

resource "aws_instance" "api" {
  ami                    = "ami-0953476d60561c955"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile   = aws_iam_instance_profile.api_profile.name
  user_data              = file("user_data.sh")

  tags = {
    Name = "parking-lot-api-instance"
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for http://${self.public_ip}:8000/ to respond..."
      for i in {1..30}; do
        if curl -s --max-time 2 http://${self.public_ip}:8000/ | grep -q "ok"; then
          echo "App is ready!"
          exit 0
        fi
        sleep 2
      done
      echo "App did not respond in time"
      exit 1
    EOT
  }
}
