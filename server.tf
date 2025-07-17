resource "aws_vpc" "cloudy" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "ebunvpc"
  }
}

resource "aws_internet_gateway" "ebungate" {
  vpc_id = aws_vpc.cloudy.id

  tags = {
    Name = "farm-igw"
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

resource "aws_route_table" "routepub" {
  vpc_id = aws_vpc.cloudy.id
  
  route {
    cidr_block = "0.0.0.0/0"            # Internet-bound traffic
    gateway_id = aws_internet_gateway.ebungate.id
  }

  tags = {
    Name = "farm-pub-route"
  }
}

resource "aws_route_table_association" "topubrt" {
  subnet_id      = aws_subnet.pubsub.id
  route_table_id = aws_route_table.routepub.id

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

resource "aws_security_group" "be-secg" {
  name        = "no-ssh"
  description = "Allow HTTP only"
  vpc_id      = aws_vpc.cloudy.id

  # Optional: allow HTTP access
  ingress {
    from_port   = 3000
    to_port     = 3000
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

resource "aws_instance" "ecpub" {
  ami                    = "ami-020cba7c55df1f615"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.pubsub.id
  vpc_security_group_ids = [aws_security_group.secg.id]  # Add this line

  tags = {
    Name = "farm-server-fe-pub"
  }
}

resource "aws_instance" "ecpub" {
  ami                    = "ami-020cba7c55df1f615"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.pubsub.id
  vpc_security_group_ids = [aws_security_group.be-secg.id]  # Add this line

  tags = {
    Name = "farm-server-be-pub"
  }
}