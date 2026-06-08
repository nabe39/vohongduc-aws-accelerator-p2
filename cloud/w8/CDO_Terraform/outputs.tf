output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "The public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnets" {
  description = "The private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "web_server_public_ip" {
  description = "The public IP of the web server"
  value       = aws_instance.web.public_ip
}

output "web_server_url" {
  description = "The URL to access the deployed web application"
  value       = "http://${aws_instance.web.public_ip}"
}

output "s3_bucket_name" {
  description = "The name of the static assets S3 bucket"
  value       = aws_s3_bucket.assets.bucket
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS MySQL instance"
  value       = aws_db_instance.db.endpoint
}

output "ssh_private_key_path" {
  description = "Path to the downloaded private key file for SSH access"
  value       = "${path.cwd}/web-key.pem"
}
