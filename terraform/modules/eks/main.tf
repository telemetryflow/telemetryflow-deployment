# ==========================================================================
#  Module EKS: main.tf
# --------------------------------------------------------------------------
#  Description:
#    EKS observability cluster - locals & common tags
# --------------------------------------------------------------------------
#    - Workspace Environment
#    - Common Tags
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
    Environment     = var.environment[local.env]
    Department      = var.department
    DepartmentGroup = "${var.environment[local.env]}-${var.department}"
    Terraform       = true
  }
}
