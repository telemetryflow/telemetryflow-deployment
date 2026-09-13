# ==========================================================================
#  Module Budget: variable.tf
# --------------------------------------------------------------------------
#  Description:
#    Budget Variables
# ==========================================================================

# --------------------------------------------------------------------------
#  AWS
# --------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "aws_account_id_destination" {
  description = "The AWS Account ID where budgets are created"
  type        = string
}

variable "aws_account_profile_destination" {
  description = "The AWS Profile to use for the budget API calls"
  type        = string
}

# --------------------------------------------------------------------------
#  Workspace
# --------------------------------------------------------------------------
variable "workspace_name" {
  description = "Workspace Environment Name"
  type        = string
}

variable "workspace_env" {
  description = "Workspace Environment Selection"
  type        = map(string)
}

# --------------------------------------------------------------------------
#  Environment Resources Tags
# --------------------------------------------------------------------------
variable "environment" {
  description = "Target Environment (tags)"
  type        = map(string)
}

variable "department" {
  description = "Department Owner"
  type        = string
}

# --------------------------------------------------------------------------
#  Budget — Monthly Forecast (alert when projected spend exceeds threshold)
# --------------------------------------------------------------------------
variable "forecast_budget_name" {
  description = "Monthly forecast budget name"
  type        = string
  default     = "tfo-monthly-forecast"
}

variable "forecast_budget_limit_amount" {
  description = "Monthly forecast budget limit (USD)"
  type        = string
  default     = "200"
}

variable "forecast_budget_threshold" {
  description = "Alert when forecasted spend exceeds this percentage of budget"
  type        = number
  default     = 80
}

variable "forecast_budget_subscriber_email" {
  description = "Email address for forecast budget alerts"
  type        = string
  default     = "support@telemetryflow.id"
}

# --------------------------------------------------------------------------
#  Budget — Monthly Actual (alert when actual spend exceeds threshold)
# --------------------------------------------------------------------------
variable "actual_budget_name" {
  description = "Monthly actual budget name"
  type        = string
  default     = "tfo-monthly-actual"
}

variable "actual_budget_limit_amount" {
  description = "Monthly actual budget limit (USD)"
  type        = string
  default     = "250"
}

variable "actual_budget_threshold" {
  description = "Alert when actual spend exceeds this percentage of budget"
  type        = number
  default     = 80
}

variable "actual_budget_subscriber_email" {
  description = "Email address for actual budget alerts"
  type        = string
  default     = "support@telemetryflow.id"
}

# --------------------------------------------------------------------------
#  Budget — Common
# --------------------------------------------------------------------------
variable "budget_time_period_start" {
  description = "Start date for budget tracking (YYYY-MM-DD_HH:MM)"
  type        = string
  default     = "2025-01-01_00:00"
}

variable "budget_limit_unit" {
  description = "Budget limit unit"
  type        = string
  default     = "USD"
}

variable "budget_time_unit" {
  description = "Budget time unit (MONTHLY, QUARTERLY, ANNUALLY)"
  type        = string
  default     = "MONTHLY"

  validation {
    condition     = contains(["MONTHLY", "QUARTERLY", "ANNUALLY"], var.budget_time_unit)
    error_message = "budget_time_unit must be MONTHLY, QUARTERLY, or ANNUALLY."
  }
}

variable "create_budgets" {
  description = "Set to false to skip budget creation (e.g. in lab workspace)"
  type        = bool
  default     = true
}
