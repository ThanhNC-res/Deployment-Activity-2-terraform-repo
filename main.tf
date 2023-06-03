provider "aws" {
   region = "ap-northeast-1"
}

#Create VPC
resource "aws_vpc" "deployactive-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags ={
    Name = "deployactive-vpc"
  }
}

resource "aws_subnet" "deployactive-public-subnet-1" {
  vpc_id = aws_vpc.deployactive-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "deployactive-public-subnet-1"
  }
}

#Create Subnets
resource "aws_subnet" "deployactive-public-subnet-2" {
  vpc_id = aws_vpc.deployactive-vpc.id
  cidr_block = "10.0.16.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "deployactive-public-subnet-2"
  }
}

resource "aws_subnet" "deployactive-private-subnet-1" {
  vpc_id = aws_vpc.deployactive-vpc.id
  cidr_block = "10.0.128.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "deployactive-private-subnet-1"
  }
}

resource "aws_subnet" "deployactive-private-subnet-2" {
  vpc_id = aws_vpc.deployactive-vpc.id
  cidr_block = "10.0.144.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "deployactive-private-subnet-2"
  }
}

resource "aws_internet_gateway" "deployactive-igw" {
  vpc_id = aws_vpc.deployactive-vpc.id

  tags = {
    Name = "deployactive-igw"
  }
}

#Create route table and associations
resource "aws_route_table" "deployactive-vpc-public-route" {
  vpc_id = aws_vpc.deployactive-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.deployactive-igw.id
  }
}

resource "aws_route_table_association" "public_subnet_assoiate_1" {
  subnet_id = aws_subnet.deployactive-public-subnet-1.id
  route_table_id = aws_route_table.deployactive-vpc-public-route.id
}

resource "aws_route_table_association" "public_subnet_assoiate_2" {
  subnet_id = aws_subnet.deployactive-public-subnet-2.id
  route_table_id = aws_route_table.deployactive-vpc-public-route.id
}

#Create Security Group for EC2 Instances
resource "aws_security_group" "deployactive-sg" {
  vpc_id = aws_vpc.deployactive-vpc.id
  name = "deployactive-sg"
  description = "Security group for deploy activity instance"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#Get AMI data
data "aws_ami" "linux" {
  # executable_users = ["self"]
  most_recent      = true
  # name_regex       = "^ami-\\d{3}"
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

variable "ami_id" {
  default = "ami-0af2f764c580cc1f9"
}

#Create ec2 instance
resource "aws_instance" "deployactive" {
  ami = data.aws_ami.linux.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.deployactive-sg.id ]
  subnet_id = aws_subnet.deployactive-public-subnet-1.id
  key_name = "thanh.nc2-key"
  associate_public_ip_address = true
  user_data = <<EOF
  #!/bin/bash
  sudo yum update -y
  sudo yum install -y php mariadb-server php-mysql httpd  
  sudo amazon-linux-extras enable php8.2
  sudo amazon-linux-extras install -y php8.2
  sudo wget "https://wordpress.org/latest.tar.gz"
  sudo tar xvfz latest.tar.gz -C /var/www/html/ --strip-components=1 wordpress
  sudo chown -R apache /var/www/html/
  sudo service httpd start 
  sudo systemctl enable mariadb
  sudo systemctl start mariadb
  EOF

  tags = {
    Name = "Deployment-Active"
  }

} 

#Create a new load balancer
# resource "aws_elb" "deployactive-elb" {
#   name               = "deployactive-elb"
#   subnets = [ aws_subnet.deployactive-public-subnet-1.id, aws_subnet.deployactive-public-subnet-2.id ]

#   # access_logs {
#   #   bucket        = "lab-bucket-thanh.nc2"
#   #   bucket_prefix = "access-log"
#   #   interval      = 60
#   # }

#   listener {
#     instance_port     = 8000
#     instance_protocol = "http"
#     lb_port           = 80
#     lb_protocol       = "http"
#   }

#   health_check {
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     timeout             = 3
#     target              = "HTTP:8000/"
#     interval            = 30
#   }

#   instances                   = [aws_instance.deployactive.id]
#   cross_zone_load_balancing   = true
#   idle_timeout                = 400
#   connection_draining         = true
#   connection_draining_timeout = 400

#   tags = {
#     Name = "deployactive-elb"
#   }
# }

#EC2 Instance public IP 
output "Deploy-Active-Public-IP" {
  value = ["${aws_instance.deployactive.*.public_ip}"]
}

# output "elb_dns_name" {
#   description = "The DNS name of the ELB"
#   value       = aws_elb.deployactive-elb.dns_name
# }

# output "elb_health_check" {
#   description = "The Health Check of the ELB"
#   value       = aws_elb.deployactive-elb.health_check
# }
# resource "aws_s3_bucket" "deploy-backup-bucket-1" {
#   bucket = "deploy-backup-bucket-1"

#   tags = {
#     Name = "deploy-backup-bucket-1"
#   }
#   force_destroy = true
# }