# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

#Configure to get my state file into terraform cloud
terraform {
  cloud {
    organization = "Cornejo-Terraform"

    workspaces {
      name = "Networking-staging-us-east"
    }
  }
}

#Define the VPC 
resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Environment = "dev_environment"
    Terraform   = "true"
  }
}

#Define VPC for my Docker SWARM Test Environment
resource "aws_vpc" "swarm-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Environment = "swarm_environment"
    Terraform   = "True"
  }

}

#Gateway
resource "aws_internet_gateway" "dev-gw" {
  vpc_id = aws_vpc.dev-vpc.id

  tags = {
    Name = "dev"
  }
}

#define VPC for SWARM
resource "aws_internet_gateway" "swarm-gw" {
  vpc_id = aws_vpc.swarm-vpc.id

  tags = {
    Name = "Swarm"
  }
  
}

#Route Table for Gateway
resource "aws_route_table" "dev_route_table" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-gw.id
  }

  tags = {
    Name = "dev"
  }
}

#Route Tables for Swarm Gateway
resource "aws_route_table" "swarm_route_table" {
  vpc_id = aws_vpc.swarm-vpc.id

  route {
    cidr_block = "0.0.0.0./0"
    gateway_id = aws_internet_gateway.swarm-gw.id
  }

  tags = {
    Name = "Swarm"
  }
  
}

#subnet for dev VPC
resource "aws_subnet" "dev_subnet" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    name = "dev"
  }
}

#subnet for SWARM VPC
resource "aws_subnet" "swarm_subnet" {
  vpc_id = aws_vpc.swarm-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "name" = "Swarm"
  }
}

#associate route table with subnet
resource "aws_route_table_association" "dev_association" {
  subnet_id      = aws_subnet.dev_subnet.id
  route_table_id = aws_route_table.dev_route_table.id
}

#associate swarm route table with subnet
resource "aws_route_table_association" "swarm_association" {
  subnet_id = aws_subnet.swarm_subnet.id
  route_table_id = aws_route_table.swarm_route_table.id
}


#create security group to restrict and allow only certain ports
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.dev-vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#create security group to restrict and allow only certain ports to SWARM Gateway
resource "aws_security_group" "swarm_allow_web" {
  name        = "Swarm_allow_web_traffic"
  description = "Swarm_allow web traffic"
  vpc_id      = aws_vpc.swarm-vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "swarm_allow_web"
  }
}

#network interface for web server
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.dev_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.dev-gw
  ]
}

#web server
resource "aws_instance" "web-server-instance" {
  ami               = "ami-09d56f8956ab235b3"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "main-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html
              EOF

  tags = {
    "name" = "web-server"
  }
}

#Import My S3 Bucket
resource "aws_s3_bucket" "my-terraform-state-jc" {
  bucket = "my-terraform-state-jc"
}





