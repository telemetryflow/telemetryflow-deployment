# ==========================================================================
#  TelemetryFlow - TFState Bootstrap: main.tf
# --------------------------------------------------------------------------
#  Description:
#    Bootstrap the S3 + DynamoDB remote state backend.
#    Run this stack FIRST, then migrate its own state into the bucket.
# --------------------------------------------------------------------------
#    - Workspace Environment
#    - Common Tags
#    - Module TFState
# ==========================================================================

# --------------------------------------------------------------------------
#  Workspace Environment
# --------------------------------------------------------------------------
locals {
  env = terraform.workspace
}

# --------------------------------------------------------------------------
#  Global Tags
# --------------------------------------------------------------------------
locals {
  tags = {
    Environment     = "${var.environment[local.env]}"
    Department      = "${var.department}"
    DepartmentGroup = "${var.environment[local.env]}-${var.department}"
    Terraform       = true
  }
}

# --------------------------------------------------------------------------
#  Reuse Module: TFState
# --------------------------------------------------------------------------
module "tfstate" {
  source = "../../../modules//tfstate"

  aws_region                      = var.aws_region
  aws_account_id_destination      = var.aws_account_id_destination
  aws_account_profile_destination = var.aws_account_profile_destination
  workspace_name                  = var.workspace_name
  workspace_env                   = var.workspace_env
  environment                     = var.environment
  department                      = var.department

  tfstate_bucket         = var.tfstate_bucket
  tfstate_dynamodb_table = var.tfstate_dynamodb_table
  tfstate_path           = var.tfstate_path
  tfstate_encrypt        = var.tfstate_encrypt
}
