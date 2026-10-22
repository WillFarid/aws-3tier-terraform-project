# -----------------------------------------------------------------------------
# .tflint.hcl
# Linting rules for the whole repo.
# -----------------------------------------------------------------------------
config {
  call_module_type = "local" # also lint the modules our environments call
}

# Core Terraform rules: naming, unused variables, deprecated syntax, etc.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS rules: invalid instance types, bad AMI settings, and so on.
# Check the latest version at github.com/terraform-linters/tflint-ruleset-aws/releases
# and update the number below if `tflint --init` complains.
plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
