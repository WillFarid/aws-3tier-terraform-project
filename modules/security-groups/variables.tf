# -----------------------------------------------------------------------------
# variables.tf (security-groups module)
# -----------------------------------------------------------------------------
variable "name" {
  description = "Name prefix for all resources, e.g. three-tier-dev."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the security groups belong to."
  type        = string
}

variable "app_port" {
  description = "Port the application listens on. The ALB forwards to this port."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port >= 1024 && var.app_port <= 65535
    error_message = "app_port must be an unprivileged port (1024-65535)."
  }
}

variable "db_port" {
  description = "Port the database listens on (5432 = PostgreSQL, 3306 = MySQL)."
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Extra tags merged onto resources."
  type        = map(string)
  default     = {}
}