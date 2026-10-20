# -----------------------------------------------------------------------------
# outputs.tf (alb module)
# -----------------------------------------------------------------------------
output "alb_arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB (point your domain here)."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Route 53 hosted zone ID of the ALB (needed for alias records)."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "Target group ARN. The Auto Scaling Group registers instances here."
  value       = aws_lb_target_group.app.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix, used by CloudWatch alarm dimensions."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix, used by CloudWatch alarm dimensions."
  value       = aws_lb_target_group.app.arn_suffix
}

output "access_logs_bucket" {
  description = "Name of the S3 bucket holding ALB access logs."
  value       = aws_s3_bucket.alb_logs.id
}