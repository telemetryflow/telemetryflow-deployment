# ==========================================================================
#  Module Budget: budget.tf
# --------------------------------------------------------------------------
#  Description:
#    AWS Budgets — two budgets per workspace:
#      1. Monthly forecast  (FORECASTED notification at threshold%)
#      2. Monthly actual    (ACTUAL notification at threshold%)
# --------------------------------------------------------------------------
#    - Budget name includes account ID for uniqueness
#    - Email subscriber per budget
# ==========================================================================

# --------------------------------------------------------------------------
#  Resource Tags
# --------------------------------------------------------------------------
locals {
  budget_tags = {
    Name          = "budget-${var.workspace_env[local.env]}"
    ResourceGroup = "${var.environment[local.env]}-BUDGET"
  }
}

# --------------------------------------------------------------------------
#  Monthly Forecast Budget
# --------------------------------------------------------------------------
resource "aws_budgets_budget" "forecast" {
  count             = var.create_budgets ? 1 : 0
  name              = "${var.forecast_budget_name}_${var.aws_account_id_destination}"
  budget_type       = "COST"
  limit_amount      = var.forecast_budget_limit_amount
  limit_unit        = var.budget_limit_unit
  time_unit         = var.budget_time_unit
  time_period_start = var.budget_time_period_start

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.forecast_budget_threshold
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.forecast_budget_subscriber_email]
  }

  tags = merge(local.tags, local.budget_tags)
}

# --------------------------------------------------------------------------
#  Monthly Actual Budget
# --------------------------------------------------------------------------
resource "aws_budgets_budget" "actual" {
  count             = var.create_budgets ? 1 : 0
  name              = "${var.actual_budget_name}_${var.aws_account_id_destination}"
  budget_type       = "COST"
  limit_amount      = var.actual_budget_limit_amount
  limit_unit        = var.budget_limit_unit
  time_unit         = var.budget_time_unit
  time_period_start = var.budget_time_period_start

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.actual_budget_threshold
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.actual_budget_subscriber_email]
  }

  tags = merge(local.tags, local.budget_tags)
}
