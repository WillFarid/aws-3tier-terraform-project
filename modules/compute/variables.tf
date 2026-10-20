# -----------------------------------------------------------------------------
# variables.tf (compute module)
# -----------------------------------------------------------------------------
variable "name" {
  description = "Name prefix for all resources, e.g. three-tier-dev."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private app subnets (one per AZ) where instances run."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Use subnets in at least 2 availability zones."
  }
}

variable "app_sg_id" {
  description = "Security group for the app tier (from the security-groups module)."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group the ASG registers instances with."
  type        = string
}

variable "app_port" {
  description = "Port the app listens on."
  type        = number
  default     = 8080
}

variable "ami_id" {
  description = <<-EOT
    AMI to launch. The default is an SSM parameter alias that AWS resolves at
    launch time to the latest Amazon Linux 2023 image, so no lookup is needed.
  EOT
  type        = string
  default     = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "min_size" {
  description = "Minimum number of instances. Keep >= 2 for high availability."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Starting number of instances (autoscaling adjusts it afterwards)."
  type        = number
  default     = 2
}

variable "cpu_target_percent" {
  description = "Average CPU the scaling policy tries to hold."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Extra tags merged onto resources and instances."
  type        = map(string)
  default     = {}
}