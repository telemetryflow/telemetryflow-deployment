# ==========================================================================
#  Module EKS: variable.tf
# --------------------------------------------------------------------------
#  Description:
#    Global Variable
# --------------------------------------------------------------------------
#    - AWS Region
#    - AWS Account ID
#    - AWS Account Profile
#    - Workspace ID
#    - Workspace Environment
#    - Global Tags
#    - KMS Key References
# ==========================================================================

# --------------------------------------------------------------------------
#  AWS
# --------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy the EKS cluster in"
  type        = string
}

variable "aws_account_id_destination" {
  description = "The AWS Account ID to deploy the EKS cluster in"
  type        = string
}

variable "aws_account_profile_destination" {
  description = "The AWS Profile to deploy the EKS cluster in"
  type        = string
}

# --------------------------------------------------------------------------
#  KMS Key
# --------------------------------------------------------------------------
variable "kms_key" {
  description = "KMS Key References (alias/...)"
  type        = map(string)
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

# --------------------------------------------------------------------------
#  Department Tags
# --------------------------------------------------------------------------
variable "department" {
  description = "Department Owner"
  type        = string
}

# --------------------------------------------------------------------------
#  Terraform State Backend references (to read the core VPC/compute stack)
# --------------------------------------------------------------------------
variable "tfstate_bucket" {
  description = "Name of bucket storing the core tfstate (network + compute)"
  type        = string
}

variable "tfstate_dynamodb_table" {
  description = "Name of DynamoDB table storing the core tfstate lock"
  type        = string
}

variable "tfstate_path" {
  description = "Path to the core .tfstate in the bucket"
  type        = string
}
