# -----------------------------------------------------------------------------
# variables.tf (rds module)
# -----------------------------------------------------------------------------
variable "name" {
  description = "Name prefix for all resources, e.g. three-tier-dev."
  type        = string
}

variable "database_subnet_ids" {
  description = "Isolated database subnets (one per AZ)."
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_ids) >= 2
    error_message = "RDS needs subnets in at least 2 availability zones."
  }
}

variable "db_sg_id" {
  description = "Security group for the database (from the security-groups module)."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL version. A major number (\"16\") lets RDS choose the current default minor."
  type        = string
  default     = "16"
}

variable "parameter_group_family" {
  description = "Parameter group family. Must match the engine major version."
  type        = string
  default     = "postgres16"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB. Set equal to allocated_storage to disable."
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the initial database."
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master username. The password is generated and stored by RDS in Secrets Manager."
  type        = string
  default     = "dbadmin"
}

variable "multi_az" {
  description = "Run a standby in a second AZ with automatic failover. true for prod."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Days to keep automated backups (1-35)."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Block accidental deletion. true for prod, false for dev."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the snapshot taken on deletion. true for dev only."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights. Some small instance classes do not support it."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags merged onto resources."
  type        = map(string)
  default     = {}
}
