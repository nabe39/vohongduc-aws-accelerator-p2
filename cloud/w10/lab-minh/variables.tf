variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy the resources"
}

variable "bucket_prefix" {
  type        = string
  default     = "macie-sensitive-data-"
  description = "Prefix for the S3 bucket used to store sample files"
}

variable "alert_email" {
  type        = string
  description = "Email address to receive Amazon Macie alert notifications"
}
