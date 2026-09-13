# Terraform Module: Budget

Creates **two AWS Cost Budgets** per workspace:

| Budget   | Type         | Alert when                          |
| -------- | ------------ | ----------------------------------- |
| Forecast | `FORECASTED` | Projected spend exceeds threshold % |
| Actual   | `ACTUAL`     | Actual spend exceeds threshold %    |

Both budgets are **monthly**, scoped to the entire AWS account, and send
email notifications when the threshold is crossed (default: 80%).

---

<!-- BEGIN_TF_DOCS -->

## Requirements

No requirements.

## Providers

| Name                                             | Version |
| ------------------------------------------------ | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws) | n/a     |

## Modules

No modules.

## Resources

| Name                                                                                                                      | Type     |
| ------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_budgets_budget.actual](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget)   | resource |
| [aws_budgets_budget.forecast](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |

## Inputs

| Name                                                                                                                              | Description                                                   | Type          | Default                      | Required |
| --------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ------------- | ---------------------------- | :------: |
| <a name="input_actual_budget_limit_amount"></a> [actual_budget_limit_amount](#input_actual_budget_limit_amount)                   | Monthly actual budget limit (USD)                             | `string`      | `"250"`                      |    no    |
| <a name="input_actual_budget_name"></a> [actual_budget_name](#input_actual_budget_name)                                           | Monthly actual budget name                                    | `string`      | `"tfo-monthly-actual"`       |    no    |
| <a name="input_actual_budget_subscriber_email"></a> [actual_budget_subscriber_email](#input_actual_budget_subscriber_email)       | Email address for actual budget alerts                        | `string`      | `"support@telemetryflow.id"` |    no    |
| <a name="input_actual_budget_threshold"></a> [actual_budget_threshold](#input_actual_budget_threshold)                            | Alert when actual spend exceeds this percentage of budget     | `number`      | `80`                         |    no    |
| <a name="input_aws_account_id_destination"></a> [aws_account_id_destination](#input_aws_account_id_destination)                   | The AWS Account ID where budgets are created                  | `string`      | n/a                          |   yes    |
| <a name="input_aws_account_profile_destination"></a> [aws_account_profile_destination](#input_aws_account_profile_destination)    | The AWS Profile to use for the budget API calls               | `string`      | n/a                          |   yes    |
| <a name="input_aws_region"></a> [aws_region](#input_aws_region)                                                                   | The AWS region                                                | `string`      | n/a                          |   yes    |
| <a name="input_budget_limit_unit"></a> [budget_limit_unit](#input_budget_limit_unit)                                              | Budget limit unit                                             | `string`      | `"USD"`                      |    no    |
| <a name="input_budget_time_period_start"></a> [budget_time_period_start](#input_budget_time_period_start)                         | Start date for budget tracking (YYYY-MM-DD_HH:MM)             | `string`      | `"2025-01-01_00:00"`         |    no    |
| <a name="input_budget_time_unit"></a> [budget_time_unit](#input_budget_time_unit)                                                 | Budget time unit (MONTHLY, QUARTERLY, ANNUALLY)               | `string`      | `"MONTHLY"`                  |    no    |
| <a name="input_create_budgets"></a> [create_budgets](#input_create_budgets)                                                       | Set to false to skip budget creation (e.g. in lab workspace)  | `bool`        | `true`                       |    no    |
| <a name="input_department"></a> [department](#input_department)                                                                   | Department Owner                                              | `string`      | n/a                          |   yes    |
| <a name="input_environment"></a> [environment](#input_environment)                                                                | Target Environment (tags)                                     | `map(string)` | n/a                          |   yes    |
| <a name="input_forecast_budget_limit_amount"></a> [forecast_budget_limit_amount](#input_forecast_budget_limit_amount)             | Monthly forecast budget limit (USD)                           | `string`      | `"200"`                      |    no    |
| <a name="input_forecast_budget_name"></a> [forecast_budget_name](#input_forecast_budget_name)                                     | Monthly forecast budget name                                  | `string`      | `"tfo-monthly-forecast"`     |    no    |
| <a name="input_forecast_budget_subscriber_email"></a> [forecast_budget_subscriber_email](#input_forecast_budget_subscriber_email) | Email address for forecast budget alerts                      | `string`      | `"support@telemetryflow.id"` |    no    |
| <a name="input_forecast_budget_threshold"></a> [forecast_budget_threshold](#input_forecast_budget_threshold)                      | Alert when forecasted spend exceeds this percentage of budget | `number`      | `80`                         |    no    |
| <a name="input_workspace_env"></a> [workspace_env](#input_workspace_env)                                                          | Workspace Environment Selection                               | `map(string)` | n/a                          |   yes    |
| <a name="input_workspace_name"></a> [workspace_name](#input_workspace_name)                                                       | Workspace Environment Name                                    | `string`      | n/a                          |   yes    |

## Outputs

| Name                                                                             | Description                     |
| -------------------------------------------------------------------------------- | ------------------------------- |
| <a name="output_actual_budget"></a> [actual_budget](#output_actual_budget)       | Monthly actual budget details   |
| <a name="output_forecast_budget"></a> [forecast_budget](#output_forecast_budget) | Monthly forecast budget details |

<!-- END_TF_DOCS -->
