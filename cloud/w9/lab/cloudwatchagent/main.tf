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

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy resources"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 Instance type"
}

# --- VPC & Networking ---
resource "aws_vpc" "cw_vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "cw-lab-vpc"
  }
}

resource "aws_internet_gateway" "cw_igw" {
  vpc_id = aws_vpc.cw_vpc.id

  tags = {
    Name = "cw-lab-igw"
  }
}

resource "aws_subnet" "cw_public_subnet" {
  vpc_id            = aws_vpc.cw_vpc.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "cw-lab-public-subnet"
  }
}

resource "aws_route_table" "cw_public_rt" {
  vpc_id = aws_vpc.cw_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cw_igw.id
  }

  tags = {
    Name = "cw-lab-public-rt"
  }
}

resource "aws_route_table_association" "cw_public_assoc" {
  subnet_id      = aws_subnet.cw_public_subnet.id
  route_table_id = aws_route_table.cw_public_rt.id
}

# --- Security Group ---
resource "aws_security_group" "cw_ec2_sg" {
  name        = "cw-ec2-sg"
  description = "Allow SSH inbound and all outbound"
  vpc_id      = aws_vpc.cw_vpc.id

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
    Name = "cw-ec2-sg"
  }
}

# --- Key Pair for SSH ---
resource "tls_private_key" "cw_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "cw_key_pair" {
  key_name   = "cw-agent-lab-key"
  public_key = tls_private_key.cw_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.cw_key.private_key_pem
  filename        = "${path.module}/cw-agent-lab-key.pem"
  file_permission = "0600"

  provisioner "local-exec" {
    interpreter = ["powershell", "-Command"]
    command     = "icacls '${path.module}/cw-agent-lab-key.pem' /inheritance:r; icacls '${path.module}/cw-agent-lab-key.pem' '/grant:r' \"$($env:USERNAME):F\""
  }
}

# --- IAM Role for EC2 CloudWatch Agent ---
resource "aws_iam_role" "cw_agent_role" {
  name = "cw-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the CloudWatchAgentServerPolicy to the IAM Role
resource "aws_iam_role_policy_attachment" "cw_agent_policy_attach" {
  role       = aws_iam_role.cw_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Create IAM Instance Profile
resource "aws_iam_instance_profile" "cw_agent_profile" {
  name = "cw-agent-profile"
  role = aws_iam_role.cw_agent_role.name
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

resource "aws_instance" "cw_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.cw_public_subnet.id
  key_name                    = aws_key_pair.cw_key_pair.key_name
  vpc_security_group_ids      = [aws_security_group.cw_ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.cw_agent_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              # Tự động hóa quá trình cài đặt và cấu hình CloudWatch Agent
              set -ex

              # 1. Cài đặt CloudWatch Agent (Tải trực tiếp gói deb cho Ubuntu từ AWS S3)
              apt-get update -y
              apt-get install -y wget
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
              dpkg -i -E /tmp/amazon-cloudwatch-agent.deb

              # 2. Tạo file cấu hình CloudWatch Agent (config.json)
              # File này cấu hình thu thập Metrics (RAM, Disk) và Logs (/var/log/syslog)
              cat <<'CW_EOF' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "run_as_user": "root"
                },
                "metrics": {
                  "aggregation_dimensions": [
                    [
                      "InstanceId"
                    ]
                  ],
                  "append_dimensions": {
                    "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
                    "ImageId": "$${aws:ImageId}",
                    "InstanceId": "$${aws:InstanceId}",
                    "InstanceType": "$${aws:InstanceType}"
                  },
                  "metrics_collected": {
                    "disk": {
                      "measurement": [
                        "used_percent"
                      ],
                      "metrics_collection_interval": 60,
                      "resources": [
                        "*"
                      ]
                    },
                    "mem": {
                      "measurement": [
                        "used_percent"
                      ],
                      "metrics_collection_interval": 60
                    }
                  }
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/syslog",
                          "log_group_name": "EC2-Syslogs",
                          "log_stream_name": "{hostname}",
                          "retention_in_days": 7
                        }
                      ]
                    }
                  }
                }
              }
              CW_EOF

              # 3. Nạp cấu hình và khởi động CloudWatch Agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config \
                -m ec2 \
                -s \
                -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

              # 4. Thêm user cwagent vào nhóm adm để có quyền đọc /var/log/syslog
              usermod -aG adm cwagent
              systemctl restart amazon-cloudwatch-agent

              # 5. Kích hoạt tự động chạy khi khởi động lại OS
              systemctl enable amazon-cloudwatch-agent
              EOF

  tags = {
    Name = "cw-agent-lab-instance"
  }
}

# --- Outputs ---
output "instance_public_ip" {
  value       = aws_instance.cw_instance.public_ip
  description = "Địa chỉ IP Public của instance EC2"
}

output "ssh_connect_command" {
  value       = "ssh -i cw-agent-lab-key.pem ubuntu@${aws_instance.cw_instance.public_ip}"
  description = "Lệnh SSH kết nối nhanh tới EC2 instance"
}
