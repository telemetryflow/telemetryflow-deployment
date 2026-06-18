# ==========================================================================
#  TelemetryFlow - TFO Budget: variable.tf
# --------------------------------------------------------------------------
#  Description:
#    Global Variables
# --------------------------------------------------------------------------
#    - AWS Region / Account / Profile
#    - Workspace Environment
#    - Budget configuration
# ==========================================================================

# --------------------------------------------------------------------------
#  AWS
# --------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_account_id_destination" {
  description = "The AWS Account ID where budgets are created"
  type        = string
  default     = "112233445566"
}

variable "aws_account_profile_destination" {
  description = "The AWS Profile to use"
  type        = string
  default     = "TFO-TF-User-Executor"
}

# --------------------------------------------------------------------------
#  Workspace
# --------------------------------------------------------------------------
variable "workspace_name" {
  description = "Workspace Environment Name"
  type        = string
  default     = "default"
}

variable "workspace_env" {
  description = "Workspace Environment Selection"
  type        = map(string)
  default = {
    default = "default"
    lab     = "rnd"
    staging = "staging"
    prod    = "prod"
  }
}

# --------------------------------------------------------------------------
#  Environment Resources Tags
# --------------------------------------------------------------------------
variable "environment" {
  description = "Target Environment (tags)"
  type        = map(string)
  default = {
    default = "DEF"
    lab     = "RND"
    staging = "STG"
    prod    = "PROD"
  }
}

variable "department" {
  description = "Department Owner"
  type        = string
  default     = "DEVOPS"
}

# --------------------------------------------------------------------------
#  Budget — Forecast (projected spend)
# --------------------------------------------------------------------------
variable "create_budgets" {
  description = "Set to false to skip budget creation (e.g. in lab)"
  type        = bool
  default     = true
}

variable "forecast_budget_name" {
  description = "Monthly forecast budget name"
  type        = string
  default     = "tfo-monthly-forecast"
}

variable "forecast_budget_limit_amount" {
  description = "Monthly forecast budget limit in USD"
  type        = string
  default     = "200"
}

variable "forecast_budget_threshold" {
  description = "Alert when forecasted spend exceeds this % of budget"
  type        = number
  default     = 80
}

variable "forecast_budget_subscriber_email" {
  description = "Email for forecast budget alerts"
  type        = string
  default     = "devops@telemetryflow.id"
}

# --------------------------------------------------------------------------
#  Budget — Actual (current spend)
# --------------------------------------------------------------------------
variable "actual_budget_name" {
  description = "Monthly actual budget name"
  type        = string
  default     = "tfo-monthly-actual"
}

variable "actual_budget_limit_amount" {
  description = "Monthly actual budget limit in USD"
  type        = string
  default     = "250"
}

variable "actual_budget_threshold" {
  description = "Alert when actual spend exceeds this % of budget"
  type        = number
  default     = 80
}

variable "actual_budget_subscriber_email" {
  description = "Email for actual budget alerts"
  type        = string
  default     = "devops@telemetryflow.id"
}

# --------------------------------------------------------------------------
#  Budget — Common
# --------------------------------------------------------------------------
variable "budget_time_period_start" {
  description = "Budget tracking start date (YYYY-MM-DD_HH:MM)"
  type        = string
  default     = "2025-01-01_00:00"
}

variable "budget_limit_unit" {
  description = "Budget limit unit"
  type        = string
  default     = "USD"
}

variable "budget_time_unit" {
  description = "Budget time unit"
  type        = string
  default     = "MONTHLY"
}
