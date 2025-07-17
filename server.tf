provider "aws" {
    region = "us-east-1"
}

resource "aws_vpc" "cloudy" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "ebunvpc"
  }
}

resource "aws_route_table" "routepub" {
  vpc_id = aws_vpc.cloudy.id
  
  route {
    cidr_block = "0.0.0.0/0"            # Internet-bound traffic
    gateway_id = aws_internet_gateway.ebungate.id
  }

  tags = {
    Name = "pubroute"
  }
}

resource "aws_route_table_association" "topubrt" {
  subnet_id      = aws_subnet.pubsub.id
  route_table_id = aws_route_table.routepub.id

}

resource "aws_route_table" "routepriv" {
  vpc_id = aws_vpc.cloudy.id

  route = []

  tags = {
    Name = "routepriv"
  }
}

resource "aws_subnet" "pubsub" {
  vpc_id            = aws_vpc.cloudy.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true 

  tags = {
    Name = "pubsub"
  }
}

resource "aws_subnet" "privsub" {
  vpc_id     = aws_vpc.cloudy.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "privsub"
  }
}

resource "aws_internet_gateway" "ebungate" {
  vpc_id = aws_vpc.cloudy.id

  tags = {
    Name = "ebungate"
  }
}

resource "aws_route_table_association" "toprivrt" {
  subnet_id      = aws_subnet.privsub.id
  route_table_id = aws_route_table.routepriv.id

}

resource "aws_security_group" "secg" {
  name        = "no-ssh"
  description = "Allow HTTP only"
  vpc_id      = aws_vpc.cloudy.id

  # Optional: allow HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ecpub" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.pubsub.id
  vpc_security_group_ids = [aws_security_group.secg.id]  # Add this line
  
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "ecpub"
  }
}

resource "aws_instance" "ecpriv" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id   = aws_subnet.privsub.id
  vpc_security_group_ids = [aws_security_group.secg.id]  # Add this line

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
  
  tags = {
    Name = "ecprivpriv"
  }
}