# ==========================================================================
#  Module TFState: main.tf
# --------------------------------------------------------------------------
#  Description:
#    S3 Bucket + DynamoDB Table for remote Terraform state
# --------------------------------------------------------------------------
#    - Workspace Environment
#    - Common Tags
# ==========================================================================

locals {
  env = terraform.workspace
}

locals {
  tags = {
    Environment     = "${var.environment[local.env]}"
    Department      = "${var.department}"
    DepartmentGroup = "${var.environment[local.env]}-${var.department}"
    Terraform       = true
  }

  bucket_name   = var.tfstate_bucket
  dynamodb_name = var.tfstate_dynamodb_table
  aws_region    = var.aws_region
}
