# ==========================================================================
#  Module TFState: output.tf
# --------------------------------------------------------------------------
#  Description
#    Output Terraform Value
# --------------------------------------------------------------------------
#    - DynamoDB ARN / ID / Stream ARN
#    - S3 Bucket Name / ARN / Region
# ==========================================================================

# --------------------------------------------------------------------------
#  DynamoDB
# --------------------------------------------------------------------------
output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.tfstate_lock.arn
}

output "dynamodb_table_id" {
  description = "ID (name) of the DynamoDB table"
  value       = aws_dynamodb_table.tfstate_lock.id
}

output "dynamodb_table_stream_arn" {
  description = "The ARN of the Table Stream"
  value       = aws_dynamodb_table.tfstate_lock.stream_arn
}

# --------------------------------------------------------------------------
#  S3 Bucket
# --------------------------------------------------------------------------
output "s3_bucket_id" {
  description = "The ID (name) of the bucket"
  value       = aws_s3_bucket.tfstate.id
}

output "s3_bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.tfstate.arn
}

output "s3_bucket_region" {
  description = "The AWS region this bucket resides in"
  value       = aws_s3_bucket.tfstate.region
}
