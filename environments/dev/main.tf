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