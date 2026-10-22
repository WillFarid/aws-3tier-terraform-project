# -----------------------------------------------------------------------------
# backend.tf
# Tells Terraform WHERE to store state.
# State maps your code to real resources. If it is lost or corrupted,
# Terraform loses track of what it built, so we store it remotely.
#
# NOTE: backend blocks cannot use variables, so values are written literally.
# These are placeholders: in a real account you create this bucket first
# (versioning on, encryption on, public access blocked).
# -----------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket       = "REPLACE-ME-tfstate-bucket-prod" # globally unique bucket name
    key          = "three-tier/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true # encrypt state at rest
    use_lockfile = true # S3 native locking (Terraform >= 1.10), no DynamoDB needed
  }
}
