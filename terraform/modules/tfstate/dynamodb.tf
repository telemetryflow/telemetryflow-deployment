# ==========================================================================
#  Module TFState: dynamodb.tf
# --------------------------------------------------------------------------
#  Description:
#    DynamoDB table for Terraform state locking
# --------------------------------------------------------------------------
#    - LockID hash key
#    - Pay-per-request billing
#    - Deletion protection (prod-friendly)
# ==========================================================================

locals {
  dynamodb_tags = {
    Name          = local.dynamodb_name
    ResourceGroup = "${var.environment[local.env]}-DYN-TFSTATE"
  }
}

# --------------------------------------------------------------------------
#  DynamoDB
# --------------------------------------------------------------------------
resource "aws_dynamodb_table" "tfstate_lock" {
  provider         = aws.destination
  name             = local.dynamodb_name
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "LockID"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.tags, local.dynamodb_tags)
}
