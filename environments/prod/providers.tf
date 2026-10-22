# -----------------------------------------------------------------------------
# providers.tf
# Configures how Terraform talks to AWS.
#
# The mock settings are switched by a variable, so the SAME code works
# offline (portfolio) and online (real deployment). No code changes needed.
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.region

  # In mock mode we pass fake keys. In real mode we pass null, which makes
  # the provider fall back to its normal credential chain (SSO, OIDC, role).
  access_key = var.mock_mode ? "mock-access-key" : null
  secret_key = var.mock_mode ? "mock-secret-key" : null

  # These three flags stop the provider from calling AWS during setup.
  skip_credentials_validation = var.mock_mode
  skip_requesting_account_id  = var.mock_mode
  skip_metadata_api_check     = var.mock_mode

  # default_tags are applied to EVERY resource this provider creates.
  # Tags drive cost reports, ownership and automation, so make them automatic.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "aws-three-tier-terraform"
    }
  }
}
