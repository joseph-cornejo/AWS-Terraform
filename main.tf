#Configure to get my state file into terraform cloud
terraform {
  cloud {
    organization = "Cornejo-Terraform"

    workspaces {
      name = "Networking-staging-us-east"
    }
  }
}

#My S3 Bucket
resource "aws_s3_bucket" "my-terraform-state-jc" {
  bucket = "my-terraform-state-jc"
}

#Define the VPC 
resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Environment = "dev_environment"
    Terraform   = "true"
  }
}

#Gateway
resource "aws_internet_gateway" "dev-gw" {
  vpc_id = aws_vpc.dev-vpc.id

  tags = {
    Name = "dev"
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

#subnet for dev VPC
resource "aws_subnet" "dev_subnet" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    name = "dev"
  }
}


#associate route table with subnet
resource "aws_route_table_association" "dev_association" {
  subnet_id      = aws_subnet.dev_subnet.id
  route_table_id = aws_route_table.dev_route_table.id
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

#network interface for web server
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.dev_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Elastic IP for web server
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.dev-gw
  ]
}

#--------------------------------------- Instances -------------------------------------------------------------------
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
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "web-server"
  }
}


#--------------------------------------- Linux VPC -------------------------------------------------------------------
#Creating this VPC with a linux box in order to practice my linux management

#Define the VPC for my Linux Enviornment 
resource "aws_vpc" "linux-vpc" {
  cidr_block = "172.31.0.0/16"

  tags = {
    Environment = "Linux_Environment"
    Terraform   = "true"
  }
}

#Linux Gateway
resource "aws_internet_gateway" "linux-gw" {
  vpc_id = aws_vpc.linux-vpc.id

  tags = {
    Name = "Linux-GW"
  }
}

#Route Table for Gateway
resource "aws_route_table" "linux_route_table" {
  vpc_id = aws_vpc.linux-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.linux-gw.id
  }

  tags = {
    Name = "Linux-RT"
  }
}

#subnet for dev VPC
resource "aws_subnet" "linux_subnet" {
  vpc_id            = aws_vpc.linux-vpc.id
  cidr_block        = "172.31.15.0/24"
  availability_zone = "us-east-1a"

  tags = {
    name = "dev"
  }
}


#associate route table with subnet
resource "aws_route_table_association" "linux_association" {
  subnet_id      = aws_subnet.linux_subnet.id
  route_table_id = aws_route_table.linux_route_table.id
}

#create security group to restrict and allow only certain ports
resource "aws_security_group" "allow_linux_web" {
  name        = "Allow_linux_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.linux-vpc.id

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
    Name = "allow_linux_traffic"
  }
}

#network interface for web server
resource "aws_network_interface" "linux-server-nic" {
  subnet_id       = aws_subnet.linux_subnet.id
  private_ips     = ["172.31.15.250"]
  security_groups = [aws_security_group.allow_linux_web.id]
}

# Elastic IP for web server
resource "aws_eip" "linux_one" {
  vpc                       = true
  network_interface         = aws_network_interface.linux-server-nic.id
  associate_with_private_ip = "172.31.15.250"
  depends_on = [
    aws_internet_gateway.linux-gw
  ]
}

resource "aws_instance" "linux-server-instance" {
  ami               = "ami-052efd3df9dad4825"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "Ubuntu"


  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.linux-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              EOF

  tags = {
    Name = "linux-server"
  }

  }