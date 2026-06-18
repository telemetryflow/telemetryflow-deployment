# ==========================================================================
#  Module TFState: variable.tf
# --------------------------------------------------------------------------
#  Description:
#    Global Variable
# --------------------------------------------------------------------------
#    - AWS Region
#    - AWS Account Profile
#    - Workspace Environment
#    - Terraform State S3 Bucket Name
#    - Terraform State DynamoDB Table
# ==========================================================================

# --------------------------------------------------------------------------
#  AWS
# --------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy tfstate"
  type        = string
}

variable "aws_account_id_destination" {
  description = "The AWS Account ID to deploy tfstate in"
  type        = string
}

variable "aws_account_profile_destination" {
  description = "The AWS Profile to deploy tfstate in"
  type        = string
}

# --------------------------------------------------------------------------
#  Workspace
# --------------------------------------------------------------------------
variable "workspace_name" {
  description = "Workspace Environment Name"
  type        = string
}

variable "workspace_env" {
  description = "Workspace Environment Selection"
  type        = map(string)
}

# --------------------------------------------------------------------------
#  Environment Resources Tags
# --------------------------------------------------------------------------
variable "environment" {
  description = "Target Environment (tags)"
  type        = map(string)
}

variable "department" {
  description = "Department Owner"
  type        = string
}

# --------------------------------------------------------------------------
#  Bucket Terraform State
# --------------------------------------------------------------------------
variable "tfstate_bucket" {
  description = "Name of bucket to store tfstate"
  type        = string
}

variable "tfstate_dynamodb_table" {
  description = "Name of dynamodb table to store tfstate lock"
  type        = string
}

variable "tfstate_path" {
  description = "Path .tfstate in Bucket"
  type        = string
}

variable "tfstate_encrypt" {
  description = "Encrypt tfstate at rest"
  type        = bool
  default     = true
}
