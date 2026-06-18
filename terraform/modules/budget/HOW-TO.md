# Terraform Module: Budget

Creates **two AWS Cost Budgets** per workspace:

| Budget   | Type         | Alert when                          |
| -------- | ------------ | ----------------------------------- |
| Forecast | `FORECASTED` | Projected spend exceeds threshold % |
| Actual   | `ACTUAL`     | Actual spend exceeds threshold %    |

Both budgets are **monthly**, scoped to the entire AWS account, and send
email notifications when the threshold is crossed (default: 80%).

## Resources

| Resource                      | Count | Description                           |
| ----------------------------- | ----- | ------------------------------------- |
| `aws_budgets_budget.forecast` | 1     | Monthly forecast budget + email alert |
| `aws_budgets_budget.actual`   | 1     | Monthly actual budget + email alert   |

## Key Variables

| Variable                           | Default                   | Description                              |
| ---------------------------------- | ------------------------- | ---------------------------------------- |
| `forecast_budget_limit_amount`     | `200`                     | Forecast budget limit in USD             |
| `forecast_budget_threshold`        | `80`                      | Alert at 80% of forecast                 |
| `forecast_budget_subscriber_email` | `devops@telemetryflow.id` | Forecast alert recipient                 |
| `actual_budget_limit_amount`       | `250`                     | Actual budget limit in USD               |
| `actual_budget_threshold`          | `80`                      | Alert at 80% of actual                   |
| `actual_budget_subscriber_email`   | `devops@telemetryflow.id` | Actual alert recipient                   |
| `budget_time_unit`                 | `MONTHLY`                 | `MONTHLY`, `QUARTERLY`, or `ANNUALLY`    |
| `budget_time_period_start`         | `2025-01-01_00:00`        | Budget tracking start date               |
| `create_budgets`                   | `true`                    | Set `false` to skip (e.g. lab workspace) |

## Outputs

- `forecast_budget` — name, limit, threshold, notification email
- `actual_budget` — name, limit, threshold, notification email

## Copyright

- Author: **Telemetri Data Indonesia Team**
- License: **Apache v2**
