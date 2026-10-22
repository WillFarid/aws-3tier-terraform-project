# -----------------------------------------------------------------------------
# outputs.tf (dev root module)
# What you would look at after an apply. Nothing here is a secret:
# the DB secret is exposed only as an ARN (an address, not the value).
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer."
  value       = module.alb.alb_dns_name
}

output "asg_name" {
  description = "Name of the app Auto Scaling Group."
  value       = module.compute.asg_name
}

output "db_endpoint" {
  description = "Database connection endpoint (host:port)."
  value       = module.rds.db_endpoint
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the DB credentials."
  value       = module.rds.master_secret_arn
}