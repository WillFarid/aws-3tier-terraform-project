# -----------------------------------------------------------------------------
# main.tf (rds module)
# Builds: KMS key, subnet group, parameter group, monitoring role, RDS instance.
# -----------------------------------------------------------------------------

# =============================================================================
# Encryption key (customer-managed)
# =============================================================================
resource "aws_kms_key" "rds" {
  # checkov:skip=CKV2_AWS_64 The AWS default key policy is used, an explicit policy needs the account ID which cannot be looked up offline
  description             = "${var.name} RDS encryption key"
  enable_key_rotation     = true # AWS rotates the key material yearly
  deletion_window_in_days = 30   # safety net: a deleted key can be recovered for 30 days

  tags = merge(var.tags, { Name = "${var.name}-rds-key" })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# =============================================================================
# Subnet group and parameter group
# =============================================================================
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-db-subnets" })
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-pg-"
  family      = var.parameter_group_family

  # Reject any connection that is not encrypted with TLS.
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Log connections and disconnections for auditing.
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = merge(var.tags, { Name = "${var.name}-pg" })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Enhanced monitoring role
# =============================================================================
data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${var.name}-rds-monitoring-role"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json

  tags = merge(var.tags, { Name = "${var.name}-rds-monitoring-role" })
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# =============================================================================
# The database
# =============================================================================
resource "aws_db_instance" "this" {
  # checkov:skip=CKV_AWS_293: Deletion protection is a variable, off in dev, on in prod
  # checkov:skip=CKV_AWS_353: Performance Insights is a variable, off in dev (micro class), on in prod
  # checkov:skip=CKV_AWS_157: Multi-AZ is a variable, off in dev to save cost, on in prod
  identifier = "${var.name}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.master_username

  # RDS generates the password, stores it in Secrets Manager (encrypted with
  # our KMS key) and can rotate it. It never appears in code or Terraform state.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds.arn

  # Storage: gp3, encrypted with our key, grows automatically up to the ceiling.
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # Network: private subnets only, reachable only through the DB security group.
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false
  multi_az               = var.multi_az
  parameter_group_name   = aws_db_parameter_group.this.name

  # Access control: allow logging in with short-lived IAM tokens as well.
  iam_database_authentication_enabled = true

  # Backups and maintenance
  backup_retention_period    = var.backup_retention_days
  backup_window              = "03:00-04:00" # UTC
  maintenance_window         = "sun:04:30-sun:05:30"
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  # Safety
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-postgres-final"

  # Observability
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.monitoring.arn
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? aws_kms_key.rds.arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  tags = merge(var.tags, { Name = "${var.name}-postgres" })

  depends_on = [aws_iam_role_policy_attachment.monitoring]
}
