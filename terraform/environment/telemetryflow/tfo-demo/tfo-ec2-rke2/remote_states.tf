# ==========================================================================
#  TelemetryFlow - TFO EC2: remote_states.tf
# --------------------------------------------------------------------------
#  Description
#    Reference the TFState bootstrap stack to read the bucket/table names.
#    (Optional - values are also duplicated in variable.tf defaults.)
# --------------------------------------------------------------------------
data "terraform_remote_state" "tfstate" {
  backend   = "s3"
  workspace = local.env

  config = {
    region         = var.aws_region
    bucket         = var.tfstate_bucket
    dynamodb_table = var.tfstate_dynamodb_table
    key            = var.tfstate_path
  }
}
