# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create VPC

resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "development"
  }
}

#Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.dev_vpc.id
}

#Route table
resource "aws_route_table" "dev_route_table" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "dev_route_table"
  }
}

#Subnet
resource "aws_subnet" "public_subnet" {
    vpc_id = aws_vpc.dev_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
  
  tags = {
      Name = "public_subnet"
  }
}
#Associate Route Table
resource "aws_route_table_association" "route_table" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.dev_route_table.id
}
#Security Group to alow ports 22-80-443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id = aws_vpc.dev_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH"
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
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
#Network interface
resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.public_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

#Elastic IP
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]

}
#Create Ubuntu Server and install and enable apache2
resource "aws_instance" "seb_server_instance" {
  ami = "ami-0574da719dca65348"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "muskeypair"

  network_interface {
    network_interface_id = aws_network_interface.web_server_nic.id
    device_index         = 0
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo sytemctl start apache2
              sudo bash -c 'echo my very first web server > /var/www/html/index.html'
              EOF
    tags = {
        Name = "web_server"
    }
}