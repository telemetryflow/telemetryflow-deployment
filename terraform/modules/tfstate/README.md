# Terraform Module: TFState Backend (S3 + DynamoDB)

Creates the remote state backend that every other stack references.

---

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version  |
| ------------------------------------------------------------------------ | -------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.9.8 |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | >= 5.72  |
| <a name="requirement_random"></a> [random](#requirement_random)          | >= 2.0   |

## Providers

| Name                                                                                 | Version |
| ------------------------------------------------------------------------------------ | ------- |
| <a name="provider_aws.destination"></a> [aws.destination](#provider_aws.destination) | >= 5.72 |

## Modules

No modules.

## Resources

| Name                                                                                                                                                                                     | Type     |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_dynamodb_table.tfstate_lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table)                                                            | resource |
| [aws_s3_bucket.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)                                                                           | resource |
| [aws_s3_bucket_lifecycle_configuration.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration)                           | resource |
| [aws_s3_bucket_ownership_controls.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls)                                     | resource |
| [aws_s3_bucket_policy.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy)                                                             | resource |
| [aws_s3_bucket_public_access_block.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)                                   | resource |
| [aws_s3_bucket_server_side_encryption_configuration.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning)                                                     | resource |

## Inputs

| Name                                                                                                                           | Description                                  | Type          | Default | Required |
| ------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- | ------------- | ------- | :------: |
| <a name="input_aws_account_id_destination"></a> [aws_account_id_destination](#input_aws_account_id_destination)                | The AWS Account ID to deploy tfstate in      | `string`      | n/a     |   yes    |
| <a name="input_aws_account_profile_destination"></a> [aws_account_profile_destination](#input_aws_account_profile_destination) | The AWS Profile to deploy tfstate in         | `string`      | n/a     |   yes    |
| <a name="input_aws_region"></a> [aws_region](#input_aws_region)                                                                | The AWS region to deploy tfstate             | `string`      | n/a     |   yes    |
| <a name="input_department"></a> [department](#input_department)                                                                | Department Owner                             | `string`      | n/a     |   yes    |
| <a name="input_environment"></a> [environment](#input_environment)                                                             | Target Environment (tags)                    | `map(string)` | n/a     |   yes    |
| <a name="input_tfstate_bucket"></a> [tfstate_bucket](#input_tfstate_bucket)                                                    | Name of bucket to store tfstate              | `string`      | n/a     |   yes    |
| <a name="input_tfstate_dynamodb_table"></a> [tfstate_dynamodb_table](#input_tfstate_dynamodb_table)                            | Name of dynamodb table to store tfstate lock | `string`      | n/a     |   yes    |
| <a name="input_tfstate_encrypt"></a> [tfstate_encrypt](#input_tfstate_encrypt)                                                 | Encrypt tfstate at rest                      | `bool`        | `true`  |    no    |
| <a name="input_tfstate_path"></a> [tfstate_path](#input_tfstate_path)                                                          | Path .tfstate in Bucket                      | `string`      | n/a     |   yes    |
| <a name="input_workspace_env"></a> [workspace_env](#input_workspace_env)                                                       | Workspace Environment Selection              | `map(string)` | n/a     |   yes    |
| <a name="input_workspace_name"></a> [workspace_name](#input_workspace_name)                                                    | Workspace Environment Name                   | `string`      | n/a     |   yes    |

## Outputs

| Name                                                                                                           | Description                           |
| -------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| <a name="output_dynamodb_table_arn"></a> [dynamodb_table_arn](#output_dynamodb_table_arn)                      | ARN of the DynamoDB table             |
| <a name="output_dynamodb_table_id"></a> [dynamodb_table_id](#output_dynamodb_table_id)                         | ID (name) of the DynamoDB table       |
| <a name="output_dynamodb_table_stream_arn"></a> [dynamodb_table_stream_arn](#output_dynamodb_table_stream_arn) | The ARN of the Table Stream           |
| <a name="output_s3_bucket_arn"></a> [s3_bucket_arn](#output_s3_bucket_arn)                                     | The ARN of the bucket                 |
| <a name="output_s3_bucket_id"></a> [s3_bucket_id](#output_s3_bucket_id)                                        | The ID (name) of the bucket           |
| <a name="output_s3_bucket_region"></a> [s3_bucket_region](#output_s3_bucket_region)                            | The AWS region this bucket resides in |

<!-- END_TF_DOCS -->
