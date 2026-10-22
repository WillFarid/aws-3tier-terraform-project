# -----------------------------------------------------------------------------
# main.tf (prod root module)
# Same modules as dev, production-grade values:
# resilience (NAT per AZ, Multi-AZ DB), protection (deletion protection,
# final snapshots) and more capacity.
# -----------------------------------------------------------------------------
locals {
  name = "${var.project}-${var.environment}" # e.g. three-tier-prod
}

module "vpc" {
  source = "../../modules/vpc"

  name     = local.name
  vpc_cidr = "10.1.0.0/16" # different from dev so they never overlap

  azs = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs   = ["10.1.0.0/24", "10.1.1.0/24"]
  private_subnet_cidrs  = ["10.1.10.0/24", "10.1.11.0/24"]
  database_subnet_cidrs = ["10.1.20.0/24", "10.1.21.0/24"]

  # Prod: one NAT gateway per AZ, so losing an AZ does not cut the other one off.
  single_nat_gateway = false

  flow_log_retention_days = 90
}

module "security_groups" {
  source = "../../modules/security-groups"

  name   = local.name
  vpc_id = module.vpc.vpc_id

  app_port = 8080
  db_port  = 5432
}

module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id

  app_port = 8080

  # PLACEHOLDER: a real ACM certificate is needed to actually apply this.
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"

  # Must be globally unique in real life; change it if you ever deploy.
  access_logs_bucket_name = "3tier-prod-alb-logs-replace-me"

  # Prod: protected from accidental deletion, logs kept longer.
  enable_deletion_protection = true
  logs_force_destroy         = false
  access_logs_retention_days = 365
}

module "compute" {
  source = "../../modules/compute"

  name               = local.name
  private_subnet_ids = module.vpc.private_subnet_ids
  app_sg_id          = module.security_groups.app_sg_id
  target_group_arn   = module.alb.target_group_arn

  app_port = 8080

  instance_type    = "t3.small"
  min_size         = 2
  max_size         = 6
  desired_capacity = 2
}

module "rds" {
  source = "../../modules/rds"

  name                = local.name
  database_subnet_ids = module.vpc.database_subnet_ids
  db_sg_id            = module.security_groups.db_sg_id

  instance_class        = "db.t4g.medium"
  allocated_storage     = 50
  max_allocated_storage = 200
  backup_retention_days = 14

  # Prod: resilient and protected.
  multi_az                     = true
  deletion_protection          = true
  skip_final_snapshot          = false
  performance_insights_enabled = true
}

# Least privilege: the app may read ONE secret and use ONE key. Nothing else.
data "aws_iam_policy_document" "app_read_db_secret" {
  statement {
    sid       = "ReadDatabaseSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.rds.master_secret_arn]
  }

  statement {
    sid       = "DecryptWithDatabaseKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [module.rds.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "app_read_db_secret" {
  name   = "read-db-secret"
  role   = module.compute.app_role_name
  policy = data.aws_iam_policy_document.app_read_db_secret.json
}