# TelemetryFlow - TFState Bootstrap

Creates the S3 bucket + DynamoDB lock table used by **all** other TelemetryFlow
Terraform stacks for remote state.

---

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version  |
| ------------------------------------------------------------------------ | -------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.9.8 |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | >= 5.72  |
| <a name="requirement_random"></a> [random](#requirement_random)          | >= 2.0   |
| <a name="requirement_tls"></a> [tls](#requirement_tls)                   | >= 3.0   |

## Providers

No providers.

## Modules

| Name                                                     | Source                    | Version |
| -------------------------------------------------------- | ------------------------- | ------- |
| <a name="module_tfstate"></a> [tfstate](#module_tfstate) | ../../../modules//tfstate | n/a     |

## Resources

No resources.

## Inputs

| Name                                                                                                                           | Description                                  | Type          | Default                                                                                                         | Required |
| ------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- | ------------- | --------------------------------------------------------------------------------------------------------------- | :------: |
| <a name="input_aws_account_id_destination"></a> [aws_account_id_destination](#input_aws_account_id_destination)                | The AWS Account ID to deploy tfstate in      | `string`      | `"112233445566"`                                                                                                |    no    |
| <a name="input_aws_account_profile_destination"></a> [aws_account_profile_destination](#input_aws_account_profile_destination) | The AWS Profile to deploy tfstate in         | `string`      | `"TFO-TF-User-Executor"`                                                                                        |    no    |
| <a name="input_aws_region"></a> [aws_region](#input_aws_region)                                                                | The AWS region to deploy tfstate             | `string`      | `"ap-southeast-1"`                                                                                              |    no    |
| <a name="input_department"></a> [department](#input_department)                                                                | Department Owner                             | `string`      | `"DEVOPS"`                                                                                                      |    no    |
| <a name="input_environment"></a> [environment](#input_environment)                                                             | Target Environment (tags)                    | `map(string)` | <pre>{<br/> "default": "DEF",<br/> "lab": "RND",<br/> "prod": "PROD",<br/> "staging": "STG"<br/>}</pre>         |    no    |
| <a name="input_tfstate_bucket"></a> [tfstate_bucket](#input_tfstate_bucket)                                                    | Name of bucket to store tfstate              | `string`      | `"tfo-tf-state-112233445566-ap-southeast-1"`                                                                    |    no    |
| <a name="input_tfstate_dynamodb_table"></a> [tfstate_dynamodb_table](#input_tfstate_dynamodb_table)                            | Name of dynamodb table to store tfstate lock | `string`      | `"tfo-ddb-tf-state-112233445566-ap-southeast-1"`                                                                |    no    |
| <a name="input_tfstate_encrypt"></a> [tfstate_encrypt](#input_tfstate_encrypt)                                                 | Encrypt tfstate at rest                      | `bool`        | `true`                                                                                                          |    no    |
| <a name="input_tfstate_path"></a> [tfstate_path](#input_tfstate_path)                                                          | Path .tfstate in Bucket                      | `string`      | `"telemetryflow/112233445566/tfstate/terraform.tfstate"`                                                        |    no    |
| <a name="input_workspace_env"></a> [workspace_env](#input_workspace_env)                                                       | Workspace Environment Selection              | `map(string)` | <pre>{<br/> "default": "default",<br/> "lab": "rnd",<br/> "prod": "prod",<br/> "staging": "staging"<br/>}</pre> |    no    |
| <a name="input_workspace_name"></a> [workspace_name](#input_workspace_name)                                                    | Workspace Environment Name                   | `string`      | `"default"`                                                                                                     |    no    |

## Outputs

No outputs.

<!-- END_TF_DOCS -->
