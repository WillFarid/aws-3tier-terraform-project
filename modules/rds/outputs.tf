# -----------------------------------------------------------------------------
# outputs.tf (rds module)
# -----------------------------------------------------------------------------
output "db_endpoint" {
  description = "Connection endpoint (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname of the database."
  value       = aws_db_instance.this.address
}

output "db_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "master_secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the master credentials."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key that encrypts the database and its secret."
  value       = aws_kms_key.rds.arn
}
