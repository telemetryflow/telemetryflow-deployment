# ==========================================================================
#  Module Budget: output.tf
# --------------------------------------------------------------------------
#  Description:
#    Output Terraform Value
# --------------------------------------------------------------------------
#    - Forecast budget info
#    - Actual budget info
# ==========================================================================

output "forecast_budget" {
  description = "Monthly forecast budget details"
  value = var.create_budgets ? {
    name             = aws_budgets_budget.forecast[0].name
    budget_type      = aws_budgets_budget.forecast[0].budget_type
    limit_amount     = aws_budgets_budget.forecast[0].limit_amount
    limit_unit       = aws_budgets_budget.forecast[0].limit_unit
    time_unit        = aws_budgets_budget.forecast[0].time_unit
    time_period      = aws_budgets_budget.forecast[0].time_period_start
    threshold        = var.forecast_budget_threshold
    threshold_type   = "PERCENTAGE"
    notification     = "FORECASTED"
    subscriber_email = var.forecast_budget_subscriber_email
  } : null
}

output "actual_budget" {
  description = "Monthly actual budget details"
  value = var.create_budgets ? {
    name             = aws_budgets_budget.actual[0].name
    budget_type      = aws_budgets_budget.actual[0].budget_type
    limit_amount     = aws_budgets_budget.actual[0].limit_amount
    limit_unit       = aws_budgets_budget.actual[0].limit_unit
    time_unit        = aws_budgets_budget.actual[0].time_unit
    time_period      = aws_budgets_budget.actual[0].time_period_start
    threshold        = var.actual_budget_threshold
    threshold_type   = "PERCENTAGE"
    notification     = "ACTUAL"
    subscriber_email = var.actual_budget_subscriber_email
  } : null
}
