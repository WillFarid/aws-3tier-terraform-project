# -----------------------------------------------------------------------------
# versions.tf (module)
# Modules declare the provider they NEED but never configure it.
# The root module (environments/dev) owns the provider configuration.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}
