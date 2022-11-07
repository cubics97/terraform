provider "aws" {
  access_key  = ""
  secret_key  = ""
  region      = "us-west-2"
}

resource "aws_instance" "testapache2" {
  ami                    = "ami-017fecd1353bcc96e"  # ubuntu server 22.04 LTS OS
  instance_type          = "t2.micro"               # cpu 설정
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id = aws_subnet.testsubnet1.id
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install -y apache2
              sudo sysctl enable --now apache2
              EOF
  user_data_replace_on_change = true

  tags = {
    Name = "Test-Apache2-server"
  }
}

resource "aws_security_group" "web-sg" {
  vpc_id = aws_vpc.testvpc.id
  name = "web-sg"
  description = "apache2-web security group for terraform"  
}

# http 인바운드 트래픽 모두 오픈
resource "aws_security_group_rule" "mysginbound" {
  type = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web-sg.id
}

# ssh 접속 모두 오픈
resource "aws_security_group_rule" "mysginbound2" {
  type = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web-sg.id
}

# 아웃바운드 트래픽 모두 오픈
resource "aws_security_group_rule" "mysgoutbound" {
  type = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"  # 모든 프로토콜
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web-sg.id
}

# apply 시, 생성된 EC2 인스턴스의 퍼블릭 IP 를 출력한다. 
output "public_ip" {
  value       = aws_instance.testapache2.public_ip
  description = "The public IP of the Instance"
}

# VPC 생성
resource "aws_vpc" "testvpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "Test-VPC"
    }    
}

# VPC의 Subnet 생성
resource "aws_subnet" "testsubnet1" {
    vpc_id = aws_vpc.testvpc.id
    cidr_block = "10.0.0.0/24"

    availability_zone = "us-west-2a"

    tags = {
      Name = "Test-Subnet1"
    }
}

# 인터넷 게이트 웨이 생성 후 생성된 VPC와 연결 
resource "aws_internet_gateway" "testigw" {
    vpc_id = aws_vpc.testvpc.id

    tags = {
        Name = "Test-IGW"
    }
}

# 생성된 VPC에 라우팅 테이블 생성
resource "aws_route_table" "testroutetable" {
    vpc_id = aws_vpc.testvpc.id

    tags = {
        Name = "Test-RouteTable"
    }
}

# 서브넷에 생성한 라우팅 테이블 연결
resource "aws_route_table_association" "myrtassociation1" {
    subnet_id = aws_subnet.testsubnet1.id
    route_table_id = aws_route_table.testroutetable.id
}

# 라우팅 테이블에 인터넷 게이트 웨이를 통한 인터넷 통신을 위한 경로 입력
resource "aws_route" "mydefaultroute" {
    route_table_id = aws_route_table.testroutetable.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.testigw.id
}