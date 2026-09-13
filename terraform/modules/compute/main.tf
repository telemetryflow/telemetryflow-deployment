# ==========================================================================
#  Module Compute: main.tf
# --------------------------------------------------------------------------
#  Description:
#    EC2 nodes (zone-a) - locals & common tags
# ==========================================================================

locals {
  env         = terraform.workspace
  prefix_name = var.prefix_name
  aws_region  = var.aws_region

  common_tags = {
    Environment     = "${var.environment[local.env]}"
    Department      = "${var.department}"
    DepartmentGroup = "${var.environment[local.env]}-${var.department}"
    Terraform       = true
  }
}
