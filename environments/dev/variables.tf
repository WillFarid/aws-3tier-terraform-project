# -----------------------------------------------------------------------------
# variables.tf
# Inputs for this environment. Each variable has a type and description,
# and validation where bad input is possible. Fail early, fail clearly.
# -----------------------------------------------------------------------------
variable "project" {
  description = "Project name, used in resource names and tags."
  type        = string
  default     = "three-tier"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project))
    error_message = "Project must be 3-20 characters: lowercase letters, numbers, hyphens."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "mock_mode" {
  description = <<-EOT
    When true, the provider uses fake credentials and skips every call to AWS.
    This lets us run validate and plan WITHOUT an AWS account.
    In a real deployment this is false and credentials come from OIDC or SSO.
  EOT
  type        = bool
  default     = true
}
