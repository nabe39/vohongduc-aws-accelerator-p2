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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- VPC Module ---
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
  environment          = var.environment
}

# --- Random Suffix for S3 bucket name ---
resource "random_string" "assets_suffix" {
  length  = 8
  special = false
  upper   = false
}

# --- S3 Static Assets Bucket ---
resource "aws_s3_bucket" "assets" {
  bucket        = "web-assets-${var.environment}-${random_string.assets_suffix.result}"
  force_destroy = true

  tags = {
    Name        = "${var.environment}-web-assets"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index_php" {
  bucket = aws_s3_bucket.assets.id
  key    = "index.php"
  source = "${path.module}/index.php"
  etag   = filemd5("${path.module}/index.php")
}

# --- Security Groups ---
resource "aws_security_group" "web_sg" {
  name        = "${var.environment}-web-sg"
  description = "Allow port 80/443 and SSH inbound to Web EC2"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change this to user IP for production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-web-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "db_sg" {
  name        = "${var.environment}-db-sg"
  description = "Allow MySQL traffic from Web SG"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-db-sg"
    Environment = var.environment
  }
}

# --- IAM Role and Instance Profile for S3 access ---
resource "aws_iam_role" "ec2_s3_role" {
  name = "${var.environment}-ec2-s3-role"

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

resource "aws_iam_policy" "s3_access" {
  name        = "${var.environment}-s3-access-policy"
  description = "Allows access to the assets S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.assets.arn,
          "${aws_s3_bucket.assets.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-s3-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# --- Key Pair ---
resource "tls_private_key" "web_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "web_key" {
  key_name   = "${var.environment}-web-key"
  public_key = tls_private_key.web_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.web_key.private_key_pem
  filename        = "${path.module}/web-key.pem"
  file_permission = "0600"

  provisioner "local-exec" {
    interpreter = ["powershell", "-Command"]
    command     = "icacls '${path.module}/web-key.pem' /inheritance:r; icacls '${path.module}/web-key.pem' '/grant:r' \"$($env:USERNAME):F\""
  }
}

# --- RDS MySQL Database ---
resource "aws_db_subnet_group" "db_subnets" {
  name        = "${var.environment}-db-subnet-group"
  subnet_ids  = module.vpc.private_subnet_ids
  description = "Subnet group for RDS database"

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "db" {
  allocated_storage      = 20
  max_allocated_storage  = 100
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name        = "${var.environment}-mysql-db"
    Environment = var.environment
  }
}

# --- EC2 Instance (Web Server) ---
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

resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnet_ids[0]
  key_name                    = aws_key_pair.web_key.key_name
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 15
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data.tftpl", {
    db_endpoint = aws_db_instance.db.endpoint
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
    s3_bucket   = aws_s3_bucket.assets.id
    aws_region  = var.aws_region
  })

  # Prevent deadlock on destroy: wait for DB to destroy after EC2 terminates
  depends_on = [
    aws_db_instance.db,
    aws_s3_bucket.assets,
    aws_s3_object.index_php
  ]

  tags = {
    Name        = "${var.environment}-web-server"
    Environment = var.environment
  }
}
