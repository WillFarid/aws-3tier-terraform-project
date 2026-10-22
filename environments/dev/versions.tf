# -----------------------------------------------------------------------------
# versions.tf
# Pins the Terraform CLI and provider versions.
# WHY: without pins, a teammate (or a CI runner) with a newer version can
# produce different results from the same code. Pinning = reproducible builds.
# -----------------------------------------------------------------------------
terraform {
  # Allow any 1.x release from 1.10 on (1.10 introduced S3 native state locking).
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"

      # "~> 5.70" means >= 5.70.0 and < 6.0.0.
      # We accept bug-fix and minor updates but block major (breaking) ones.
      version = "~> 5.70"
    }
  }
}
