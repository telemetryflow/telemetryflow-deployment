# TelemetryFlow - TFO Budget (AWS Cost Budgets)

Creates **two account-scoped AWS Cost Budgets** per workspace: a forecast
budget (projected spend) and an actual budget (current spend). Both send
email alerts at the configured threshold (default 80%).

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.72 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_budget"></a> [budget](#module\_budget) | ../../../modules//budget | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_actual_budget_limit_amount"></a> [actual\_budget\_limit\_amount](#input\_actual\_budget\_limit\_amount) | Monthly actual budget limit in USD | `string` | `"250"` | no |
| <a name="input_actual_budget_name"></a> [actual\_budget\_name](#input\_actual\_budget\_name) | Monthly actual budget name | `string` | `"tfo-monthly-actual"` | no |
| <a name="input_actual_budget_subscriber_email"></a> [actual\_budget\_subscriber\_email](#input\_actual\_budget\_subscriber\_email) | Email for actual budget alerts | `string` | `"devops@telemetryflow.id"` | no |
| <a name="input_actual_budget_threshold"></a> [actual\_budget\_threshold](#input\_actual\_budget\_threshold) | Alert when actual spend exceeds this % of budget | `number` | `80` | no |
| <a name="input_aws_account_id_destination"></a> [aws\_account\_id\_destination](#input\_aws\_account\_id\_destination) | The AWS Account ID where budgets are created | `string` | `"112233445566"` | no |
| <a name="input_aws_account_profile_destination"></a> [aws\_account\_profile\_destination](#input\_aws\_account\_profile\_destination) | The AWS Profile to use | `string` | `"TFO-TF-User-Executor"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region | `string` | `"ap-southeast-1"` | no |
| <a name="input_budget_limit_unit"></a> [budget\_limit\_unit](#input\_budget\_limit\_unit) | Budget limit unit | `string` | `"USD"` | no |
| <a name="input_budget_time_period_start"></a> [budget\_time\_period\_start](#input\_budget\_time\_period\_start) | Budget tracking start date (YYYY-MM-DD\_HH:MM) | `string` | `"2025-01-01_00:00"` | no |
| <a name="input_budget_time_unit"></a> [budget\_time\_unit](#input\_budget\_time\_unit) | Budget time unit | `string` | `"MONTHLY"` | no |
| <a name="input_create_budgets"></a> [create\_budgets](#input\_create\_budgets) | Set to false to skip budget creation (e.g. in lab) | `bool` | `true` | no |
| <a name="input_department"></a> [department](#input\_department) | Department Owner | `string` | `"DEVOPS"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Target Environment (tags) | `map(string)` | <pre>{<br/>  "default": "DEF",<br/>  "lab": "RND",<br/>  "prod": "PROD",<br/>  "staging": "STG"<br/>}</pre> | no |
| <a name="input_forecast_budget_limit_amount"></a> [forecast\_budget\_limit\_amount](#input\_forecast\_budget\_limit\_amount) | Monthly forecast budget limit in USD | `string` | `"200"` | no |
| <a name="input_forecast_budget_name"></a> [forecast\_budget\_name](#input\_forecast\_budget\_name) | Monthly forecast budget name | `string` | `"tfo-monthly-forecast"` | no |
| <a name="input_forecast_budget_subscriber_email"></a> [forecast\_budget\_subscriber\_email](#input\_forecast\_budget\_subscriber\_email) | Email for forecast budget alerts | `string` | `"devops@telemetryflow.id"` | no |
| <a name="input_forecast_budget_threshold"></a> [forecast\_budget\_threshold](#input\_forecast\_budget\_threshold) | Alert when forecasted spend exceeds this % of budget | `number` | `80` | no |
| <a name="input_workspace_env"></a> [workspace\_env](#input\_workspace\_env) | Workspace Environment Selection | `map(string)` | <pre>{<br/>  "default": "default",<br/>  "lab": "rnd",<br/>  "prod": "prod",<br/>  "staging": "staging"<br/>}</pre> | no |
| <a name="input_workspace_name"></a> [workspace\_name](#input\_workspace\_name) | Workspace Environment Name | `string` | `"default"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->