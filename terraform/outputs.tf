# outputs.tf

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private.id
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "elastic_ip" {
  description = "Static Elastic IP - this never changes"
  value       = aws_eip.web.public_ip
}

output "s3_bucket_name" {
  description = "App S3 bucket name"
  value       = aws_s3_bucket.app_bucket.bucket
}

output "app_url" {
  description = "Flask app URL - static, never changes"
  value       = "http://${aws_eip.web.public_ip}"
}
