terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "first" {
  bucket_prefix = "tf-series-bai2-"
  force_destroy = true

  tags = {
    Project = "terraform-series"
    Bai     = "02"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.first.id
}

output "bucket_arn" {
  value = aws_s3_bucket.first.arn
}

