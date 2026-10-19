# -----------------------------------------------------------------------------
# outputs.tf (vpc module)
# What other modules (security groups, ALB, compute, RDS) need from the VPC.
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private app subnets."
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of the isolated database subnets."
  value       = aws_subnet.database[*].id
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways (useful for allow-listing)."
  value       = aws_eip.nat[*].public_ip
}