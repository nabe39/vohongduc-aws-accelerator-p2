output "s3_bucket_name" {
  value       = aws_s3_bucket.macie_bucket.id
  description = "The name of the S3 bucket created for scanning"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.macie_alerts.arn
  description = "The ARN of the SNS Topic for Macie alerts"
}

output "macie_job_id" {
  value       = aws_macie2_classification_job.macie_job.id
  description = "The ID of the Macie classification job"
}

output "macie_job_status" {
  value       = aws_macie2_classification_job.macie_job.job_status
  description = "The current status of the Macie classification job"
}
