# TelemetryFlow - TFO Budget (AWS Cost Budgets)

Creates **two account-scoped AWS Cost Budgets** per workspace: a forecast
budget (projected spend) and an actual budget (current spend). Both send
email alerts at the configured threshold (default 80%).

## Prerequisites

1. The `_tfstate` stack must already be applied (S3 bucket + DynamoDB exist).
2. Your AWS profile must have `aws-budgets:*` permissions.

## Deploy

```
cd environment/telemetryflow/tfo-budget

cp backend.tf.example backend.tf   # edit bucket/key for your account
terraform init

terraform workspace new default    # or: lab / staging / prod
terraform plan
terraform apply
```

## What gets created

| Module  | Resource                                              |
| ------- | ----------------------------------------------------- |
| budget  | `aws_budgets_budget.forecast` — forecast + email alert |
| budget  | `aws_budgets_budget.actual` — actual + email alert     |

## Key toggles

| Variable                        | Default                     | Effect                                   |
| ------------------------------- | --------------------------- | ---------------------------------------- |
| `create_budgets`                | `true`                      | `false` skips all budget creation         |
| `forecast_budget_limit_amount`  | `200`                       | Forecast budget limit (USD/month)        |
| `actual_budget_limit_amount`    | `250`                       | Actual budget limit (USD/month)          |
| `forecast_budget_threshold`     | `80`                        | Alert at 80% of forecast                 |
| `actual_budget_threshold`       | `80`                        | Alert at 80% of actual                   |
| `forecast_budget_subscriber_email` | `devops@telemetryflow.id` | Alert recipient                          |
| `budget_time_unit`              | `MONTHLY`                   | `MONTHLY`, `QUARTERLY`, or `ANNUALLY`    |

## Per-workspace limits

Override budget limits per workspace using `terraform.tfvars` and workspace
selection:

```
terraform workspace select prod
terraform apply -var="actual_budget_limit_amount=500"
```

Or set different amounts in separate tfvars files per workspace.

## Cleanup

```
terraform workspace select default
terraform destroy
```

## Copyright

- Author: **Telemetri Data Indonesia Team**
- License: **Apache v2**
