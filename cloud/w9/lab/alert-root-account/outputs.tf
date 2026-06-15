output "cloudtrail_s3_bucket" {
  value       = aws_s3_bucket.cloudtrail_bucket.id
  description = "Tên S3 Bucket lưu trữ CloudTrail logs"
}

output "cloudtrail_log_group_name" {
  value       = aws_cloudwatch_log_group.cloudtrail_log_group.name
  description = "Tên CloudWatch Log Group nhận log từ CloudTrail"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.root_login_topic.arn
  description = "ARN của SNS Topic để gửi cảnh báo"
}

output "alarm_name" {
  value       = aws_cloudwatch_metric_alarm.root_login_alarm.alarm_name
  description = "Tên của CloudWatch Alarm"
}

output "target_email" {
  value       = local.alert_email
  description = "Email nhận cảnh báo được trích xuất từ alertmanager.env"
}
