data "aws_caller_identity" "current" {}

# 1. Amazon Macie Account Activation
# Note: If Macie is already enabled in the account, this might fail unless imported.
# We will use this resource so the user can easily deploy/destroy the entire infrastructure.
resource "aws_macie2_account" "macie" {
  status = "ENABLED"
}

# 2. S3 Bucket for Scanning
resource "aws_s3_bucket" "macie_bucket" {
  bucket_prefix = var.bucket_prefix
  force_destroy = true # Allows easy cleanup of the bucket during terraform destroy
}

resource "aws_s3_bucket_public_access_block" "macie_bucket_pab" {
  bucket                  = aws_s3_bucket.macie_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Upload Sample CSV Files (Mock Sensitive and Clean Data)
resource "aws_s3_object" "sensitive_data" {
  bucket = aws_s3_bucket.macie_bucket.id
  key    = "sensitive/sample_sensitive_data.csv"
  source = "${path.module}/sample_sensitive_data.csv"
  etag   = filemd5("${path.module}/sample_sensitive_data.csv")
}

resource "aws_s3_object" "clean_data" {
  bucket = aws_s3_bucket.macie_bucket.id
  key    = "clean/sample_clean_data.csv"
  source = "${path.module}/sample_clean_data.csv"
  etag   = filemd5("${path.module}/sample_clean_data.csv")
}

# 4. Amazon Simple Notification Service (SNS) Topic & Subscription
resource "aws_sns_topic" "macie_alerts" {
  name = "macie-sensitive-data-alerts"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.macie_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SNS Topic Policy to allow EventBridge to publish to it
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.macie_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.macie_alerts.arn]
  }
}

# 5. Amazon EventBridge (CloudWatch Events) Rule & Target
resource "aws_cloudwatch_event_rule" "macie_rule" {
  name        = "macie-sensitive-data-findings"
  description = "Trigger alerts on Amazon Macie findings"

  event_pattern = jsonencode({
    source        = ["aws.macie"]
    "detail-type" = ["Macie Finding"]
  })
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.macie_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.macie_alerts.arn

  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity.description"
      bucket_name  = "$.detail.resourcesAffected.s3Bucket.name"
      object_path  = "$.detail.resourcesAffected.s3Object.key"
      finding_id   = "$.detail.id"
      region       = "$.region"
    }

    input_template = jsonencode("Alert: Amazon Macie has detected sensitive data!\n\nFinding Details:\n- Finding Type: <finding_type>\n- Severity: <severity>\n- Affected S3 Bucket: <bucket_name>\n- Affected File: <object_path>\n- Finding ID: <finding_id>\n- AWS Region: <region>\n\nPlease check the Amazon Macie console for detailed remediation steps.")
  }
}

# 6. Amazon Macie Classification Job
resource "aws_macie2_classification_job" "macie_job" {
  depends_on = [
    aws_macie2_account.macie,
    aws_s3_object.sensitive_data,
    aws_s3_object.clean_data
  ]

  name        = "macie-s3-sensitive-data-scan"
  job_type    = "ONE_TIME"
  job_status  = "RUNNING"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.macie_bucket.id]
    }
  }

  sampling_percentage = 100
}
