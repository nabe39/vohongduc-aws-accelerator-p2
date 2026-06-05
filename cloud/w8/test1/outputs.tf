output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "app_url" {
  value = "http://${aws_lb.app.dns_name}"
}

output "ec2_instance_id" {
  value = aws_instance.k8s.id
}