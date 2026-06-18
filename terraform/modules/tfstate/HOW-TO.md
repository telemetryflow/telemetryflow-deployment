# Terraform Module: TFState Backend (S3 + DynamoDB)

Creates the remote state backend that every other stack references.

## Resources

| Resource                                  | Description                          |
| ----------------------------------------- | ------------------------------------ |
| `aws_s3_bucket`                           | Private bucket for `.tfstate` files  |
| `aws_s3_bucket_versioning`                | Versioning enabled                   |
| `aws_s3_bucket_server_side_encryption_*`  | SSE-S3 (AES256) encryption           |
| `aws_s3_bucket_public_access_block`       | Block all public access              |
| `aws_s3_bucket_policy`                    | Deny non-TLS (insecure) transport    |
| `aws_s3_bucket_lifecycle_configuration`   | Expire non-current versions (90d)    |
| `aws_dynamodb_table`                      | `LockID` table for state locking     |

> **Bootstrap note:** This module must be applied with a **local** state first
> (`backend.tf.example` left disabled), then migrated to the S3 backend it
> creates via `terraform init --migrate-state`.

## Outputs

- `s3_bucket_id`, `s3_bucket_arn`, `s3_bucket_region`
- `dynamodb_table_arn`, `dynamodb_table_id`, `dynamodb_table_stream_arn`

## Copyright

- Author: **Telemetri Data Indonesia Team**
- License: **Apache v2**
