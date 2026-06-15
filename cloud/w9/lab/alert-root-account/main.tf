terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

# --- Caller Identity for AWS Account ID ---
data "aws_caller_identity" "current" {}

# --- S3 Bucket for CloudTrail Logs ---
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket        = "aws-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "cloudtrail-logs-bucket"
    Environment = "Security"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_bucket_public_access" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.cloudtrail_bucket_public_access
  ]
}

# --- CloudWatch Log Group for CloudTrail ---
resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "aws-cloudtrail-logs"
  retention_in_days = 7

  tags = {
    Name        = "cloudtrail-log-group"
    Environment = "Security"
  }
}

# --- IAM Role and Policy for CloudTrail to send logs to CloudWatch ---
resource "aws_iam_role" "cloudtrail_to_cloudwatch_role" {
  name = "cloudtrail-to-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_to_cloudwatch_policy" {
  name = "cloudtrail-to-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_to_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
      }
    ]
  })
}

# --- AWS CloudTrail Trail ---
resource "aws_cloudtrail" "security_trail" {
  name                          = "root-account-login-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cloudwatch_role.arn
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"

  depends_on = [
    aws_s3_bucket_policy.cloudtrail_bucket_policy,
    aws_iam_role_policy.cloudtrail_to_cloudwatch_policy
  ]

  tags = {
    Name        = "root-account-login-trail"
    Environment = "Security"
  }
}

# --- CloudWatch Metric Filter ---
resource "aws_cloudwatch_log_metric_filter" "root_login_filter" {
  name           = "RootAccountLoginFilter"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.eventType != \"AwsServiceEvent\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_log_group.name

  metric_transformation {
    name      = "RootAccountLoginCount"
    namespace = "Security"
    value     = "1"
  }
}

# --- AWS SNS Topic & Subscription ---
resource "aws_sns_topic" "root_login_topic" {
  name = "root-account-login-topic"

  tags = {
    Name        = "root-account-login-topic"
    Environment = "Security"
  }
}

resource "aws_sns_topic_subscription" "root_login_email_sub" {
  topic_arn = aws_sns_topic.root_login_topic.arn
  protocol  = "email"
  endpoint  = local.alert_email
}

# --- CloudWatch Metric Alarm ---
resource "aws_cloudwatch_metric_alarm" "root_login_alarm" {
  alarm_name          = "RootAccountLoginAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.root_login_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.root_login_filter.metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm when AWS Root Account login is detected"

  alarm_actions = [aws_sns_topic.root_login_topic.arn]

  tags = {
    Name        = "RootAccountLoginAlarm"
    Environment = "Security"
  }
}
