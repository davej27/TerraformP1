terraform {
  required_version = ">= 0.13"
  required_providers {
   aws = {
     source  = "hashicorp/aws"
     version = "~> 3.0"
   }
 }
}
# Provider and access\secret key
provider "aws" {
    region  = "us-east-1"
     access_key = "<access key>"
     secret_key = "<secret key>"
}

# Creating of VPC
resource "aws_vpc" "FirstVPC" {
    cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Production"
  }
}

# Creating of Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.FirstVPC.id
}

# Creating route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.FirstVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}


# Creating of subnet
resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.FirstVPC.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

 tags = {
    Name = "Prod-Subnet"
  }
}


# Assoicate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

#Creating of EC2 Instance
resource "aws_instance" "fooBar" {
  ami           = "ami-08e4e35cccc6189f4" # us-west-2
  instance_type = "t2.micro"

  tags = {
    Name = "First_EC2_Through_Terraform"
  }
}

#Creating of security group
resource "aws_security_group" "allow_web_1" {
  name        = "allow_Web_Traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.FirstVPC.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
      }

ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
      }

ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
      }

egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#creating of network interface

resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_1.id]
}

#Creating of Elastic IP

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                 = [aws_internet_gateway.gw]
}


# Creating of ubantu server

resource "aws_instance" "ubantu" {
  ami           = "ami-04505e74c0741db8d" # us-west-2
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web_server_nic.id
    }
  
  tags = {
    Name = "Secound_EC2_Through_Terraform"
  }

  user_data = <<-EOF
          #!/bin/bash
          sudo apt update -y
          sudo apt install apache2 -y
          sudo systemct1 start apache2
          sudo bash -c 'echo you very first web server > /var/www/html/index.html'
          EOF
}




