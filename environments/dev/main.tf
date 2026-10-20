# -----------------------------------------------------------------------------
# main.tf (dev root module)
# Calls the child modules with dev-sized values.
# -----------------------------------------------------------------------------
locals {
  name = "${var.project}-${var.environment}" # e.g. three-tier-dev
}

module "vpc" {
  source = "../../modules/vpc" # up two folders (dev -> environments -> repo), then modules/vpc

  name     = local.name
  vpc_cidr = "10.0.0.0/16"

  # Passed in, not looked up, so plan works without an AWS account.
  azs = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs   = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]

  # Dev saves money with one shared NAT gateway.
  single_nat_gateway = true
}

module "security_groups" {
  source = "../../modules/security-groups"

  name   = local.name
  vpc_id = module.vpc.vpc_id # output of the VPC module: this creates the dependency

  app_port = 8080
  db_port  = 5432 # PostgreSQL, which we'll use for RDS
}

module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id # chained from Step 3

  app_port = 8080 # must match the security_groups module

  # PLACEHOLDER: a real ACM certificate is needed to actually apply this.
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"

  # Must be globally unique in real life; change it if you ever deploy.
  access_logs_bucket_name = "3tier-dev-alb-logs-replace-me"

  # Dev is disposable: allow easy cleanup. Prod will flip both of these.
  enable_deletion_protection = false
  logs_force_destroy         = true
}

module "compute" {
  source = "../../modules/compute"

  name               = local.name
  private_subnet_ids = module.vpc.private_subnet_ids
  app_sg_id          = module.security_groups.app_sg_id
  target_group_arn   = module.alb.target_group_arn # ASG registers instances here

  app_port = 8080 # must match the SG and ALB modules

  # Dev is small and cheap. Prod will use larger values.
  instance_type    = "t3.micro"
  min_size         = 2
  max_size         = 4
  desired_capacity = 2
}