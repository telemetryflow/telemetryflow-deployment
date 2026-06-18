# ==========================================================================
#  TelemetryFlow - TFO Budget: main.tf
# --------------------------------------------------------------------------
#  Description:
#    AWS Cost Budgets — forecast + actual (account-scoped, per workspace)
# --------------------------------------------------------------------------
#    - Workspace Environment
#    - Common Tags
#    - Module Budget (2 budgets: forecast + actual)
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
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id_destination

  tags = {
    Environment     = var.environment[local.env]
    Department      = var.department
    DepartmentGroup = "${var.environment[local.env]}-${var.department}"
    Terraform       = true
  }
}

# --------------------------------------------------------------------------
#  Reuse Module: Budget (forecast + actual)
# --------------------------------------------------------------------------
module "budget" {
  source = "../../../modules//budget"

  aws_region                      = var.aws_region
  aws_account_id_destination      = var.aws_account_id_destination
  aws_account_profile_destination = var.aws_account_profile_destination
  workspace_name                  = var.workspace_name
  workspace_env                   = var.workspace_env
  environment                     = var.environment
  department                      = var.department

  create_budgets = var.create_budgets

  forecast_budget_name             = var.forecast_budget_name
  forecast_budget_limit_amount     = var.forecast_budget_limit_amount
  forecast_budget_threshold        = var.forecast_budget_threshold
  forecast_budget_subscriber_email = var.forecast_budget_subscriber_email

  actual_budget_name             = var.actual_budget_name
  actual_budget_limit_amount     = var.actual_budget_limit_amount
  actual_budget_threshold        = var.actual_budget_threshold
  actual_budget_subscriber_email = var.actual_budget_subscriber_email

  budget_time_period_start = var.budget_time_period_start
  budget_limit_unit        = var.budget_limit_unit
  budget_time_unit         = var.budget_time_unit
}
