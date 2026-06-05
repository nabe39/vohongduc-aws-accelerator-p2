output "alb_dns_name" {
  value       = "http://${aws_lb.main.dns_name}"
  description = "The DNS name of the Application Load Balancer to access the web application."
}

output "ec2_public_ip" {
  value       = aws_instance.k8s_node.public_ip
  description = "The public IP address of the EC2 instance hosting the Kubernetes cluster."
}
