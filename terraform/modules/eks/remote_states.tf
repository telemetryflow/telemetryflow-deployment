# ==========================================================================
#  Module EKS: remote_states.tf (Remote Terraform References)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Reads VPC / subnet / SG outputs from the tfo-ec2 core stack
#    - Backend values are passed in from the environment wiring
# ==========================================================================

# --------------------------------------------------------------------------
#  Use Existing Core Terraform Remote State (network + compute)
# --------------------------------------------------------------------------
data "terraform_remote_state" "core_state" {
  backend   = "s3"
  workspace = local.env

  config = {
    region         = var.aws_region
    bucket         = var.tfstate_bucket
    dynamodb_table = var.tfstate_dynamodb_table
    key            = var.tfstate_path
  }
}
