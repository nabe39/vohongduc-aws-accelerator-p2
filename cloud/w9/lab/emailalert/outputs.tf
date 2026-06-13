output "instance_public_ip" {
  value       = aws_instance.email_alert_instance.public_ip
  description = "Địa chỉ IP Public của instance EC2"
}

output "ssh_connect_command" {
  value       = "ssh -i email-alert-lab-key.pem ubuntu@${aws_instance.email_alert_instance.public_ip}"
  description = "Lệnh SSH kết nối nhanh tới EC2 instance"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.cpu_alarm_topic.arn
  description = "ARN của SNS Topic"
}

output "alarm_name" {
  value       = aws_cloudwatch_metric_alarm.ec2_cpu_alarm.alarm_name
  description = "Tên của CloudWatch Metric Alarm"
}

output "target_email" {
  value       = local.alert_email
  description = "Email nhận cảnh báo được trích xuất từ alertmanager.env"
}
