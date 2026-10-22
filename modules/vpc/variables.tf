# -----------------------------------------------------------------------------
# variables.tf (vpc module)
# The module's "API": everything a caller can customize.
# -----------------------------------------------------------------------------
variable "name" {
  description = "Name prefix for all resources, e.g. three-tier-dev."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones to use. Passed in (not looked up) so plan works without AWS credentials."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Use at least 2 availability zones for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets, one per AZ (ALB, NAT gateways)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private app subnets, one per AZ (EC2 instances)."
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "CIDRs for isolated database subnets, one per AZ (RDS)."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheap, for dev). false = one NAT per AZ (resilient, for prod)."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "How long to keep VPC flow logs in CloudWatch."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Extra tags merged onto resources (provider default_tags are applied automatically)."
  type        = map(string)
  default     = {}
}
