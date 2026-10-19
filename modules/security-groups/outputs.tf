# -----------------------------------------------------------------------------
# outputs.tf (security-groups module)
# The ALB, compute and RDS modules attach these security groups.
# -----------------------------------------------------------------------------
output "alb_sg_id" {
  description = "ID of the load balancer security group."
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "ID of the app tier security group."
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "ID of the database security group."
  value       = aws_security_group.db.id
}