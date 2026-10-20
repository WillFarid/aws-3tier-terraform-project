# -----------------------------------------------------------------------------
# outputs.tf (compute module)
# -----------------------------------------------------------------------------
output "asg_name" {
  description = "Name of the Auto Scaling Group (used by monitoring)."
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "ID of the launch template."
  value       = aws_launch_template.app.id
}

output "app_role_name" {
  description = "Name of the instance IAM role. Attach extra policies to this."
  value       = aws_iam_role.app.name
}

output "app_role_arn" {
  description = "ARN of the instance IAM role."
  value       = aws_iam_role.app.arn
}