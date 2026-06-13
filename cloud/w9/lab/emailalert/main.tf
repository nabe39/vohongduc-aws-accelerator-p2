terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Load and Parse alertmanager.env for Email ---
locals {
  env_content = file("${path.module}/../gitops/k8s/alertmanager.env")
  alert_email = regex("ALERT_TO_EMAIL\\s*=\\s*\"(?P<email>[^\"]+)\"", local.env_content).email
}

# --- VPC & Networking ---
resource "aws_vpc" "email_alert_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "email-alert-vpc"
  }
}

resource "aws_internet_gateway" "email_alert_igw" {
  vpc_id = aws_vpc.email_alert_vpc.id

  tags = {
    Name = "email-alert-igw"
  }
}

resource "aws_subnet" "email_alert_public_subnet" {
  vpc_id            = aws_vpc.email_alert_vpc.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "email-alert-public-subnet"
  }
}

resource "aws_route_table" "email_alert_public_rt" {
  vpc_id = aws_vpc.email_alert_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.email_alert_igw.id
  }

  tags = {
    Name = "email-alert-public-rt"
  }
}

resource "aws_route_table_association" "email_alert_public_assoc" {
  subnet_id      = aws_subnet.email_alert_public_subnet.id
  route_table_id = aws_route_table.email_alert_public_rt.id
}

# --- Security Group ---
resource "aws_security_group" "email_alert_ec2_sg" {
  name        = "email-alert-ec2-sg"
  description = "Allow SSH inbound and all outbound"
  vpc_id      = aws_vpc.email_alert_vpc.id

  ingress {
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
    Name = "email-alert-ec2-sg"
  }
}

# --- Key Pair for SSH ---
resource "tls_private_key" "email_alert_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "email_alert_key_pair" {
  key_name   = "email-alert-lab-key"
  public_key = tls_private_key.email_alert_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.email_alert_key.private_key_pem
  filename        = "${path.module}/email-alert-lab-key.pem"
  file_permission = "0600"

  provisioner "local-exec" {
    interpreter = ["powershell", "-Command"]
    command     = "icacls '${path.module}/email-alert-lab-key.pem' /inheritance:r; icacls '${path.module}/email-alert-lab-key.pem' '/grant:r' \"$($env:USERNAME):F\""
  }
}

# --- EC2 Instance ---
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

resource "aws_instance" "email_alert_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.email_alert_public_subnet.id
  key_name                    = aws_key_pair.email_alert_key_pair.key_name
  vpc_security_group_ids      = [aws_security_group.email_alert_ec2_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Automatically install stress utility to help with CPU testing
  user_data = <<-EOF
              #!/bin/bash
              set -ex
              apt-get update -y
              apt-get install -y stress stress-ng
              EOF

  tags = {
    Name = "email-alert-lab-instance"
  }
}

# --- SNS Topic & Subscription ---
resource "aws_sns_topic" "cpu_alarm_topic" {
  name = "ec2-cpu-alarm-topic"

  tags = {
    Name = "ec2-cpu-alarm-topic"
  }
}

resource "aws_sns_topic_subscription" "cpu_alarm_email_sub" {
  topic_arn = aws_sns_topic.cpu_alarm_topic.arn
  protocol  = "email"
  endpoint  = local.alert_email
}

# --- CloudWatch Metric Alarm ---
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_alarm" {
  alarm_name          = "ec2-high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # 5 minutes (as per slide: "Period: 5 minutes | Evaluation: 1 out of 1 datapoints")
  statistic           = "Average"
  threshold           = 80 # Greater than 80%
  alarm_description   = "Alarm when EC2 CPU utilization exceeds 80% for 5 consecutive minutes"
  
  dimensions = {
    InstanceId = aws_instance.email_alert_instance.id
  }

  alarm_actions = [aws_sns_topic.cpu_alarm_topic.arn]
  ok_actions    = [aws_sns_topic.cpu_alarm_topic.arn] # Recovery alert when CPU goes back to normal
}
