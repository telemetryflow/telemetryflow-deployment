# ==========================================================================
#  TelemetryFlow - TFState Bootstrap: variable.tf
# --------------------------------------------------------------------------
#  Description:
#    Global Variable
# --------------------------------------------------------------------------
#    - AWS Region
#    - AWS Account ID
#    - AWS Account Profile
#    - Workspace Environment
#    - Global Tags
#    - Terraform State S3 Bucket Name
#    - Terraform State S3 Key (Prefix)
#    - Terraform State S3 DynamoDB Table
# ==========================================================================

# --------------------------------------------------------------------------
#  AWS
# --------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy tfstate"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_account_id_destination" {
  description = "The AWS Account ID to deploy tfstate in"
  type        = string
  default     = "112233445566"
}

variable "aws_account_profile_destination" {
  description = "The AWS Profile to deploy tfstate in"
  type        = string
  default     = "TFO-TF-User-Executor"
}

# --------------------------------------------------------------------------
#  Workspace
# --------------------------------------------------------------------------
variable "workspace_name" {
  description = "Workspace Environment Name"
  type        = string
  default     = "default"
}

variable "workspace_env" {
  description = "Workspace Environment Selection"
  type        = map(string)
  default = {
    default = "default"
    lab     = "rnd"
    staging = "staging"
    prod    = "prod"
  }
}

# --------------------------------------------------------------------------
#  Environment Resources Tags
# --------------------------------------------------------------------------
variable "environment" {
  description = "Target Environment (tags)"
  type        = map(string)
  default = {
    default = "DEF"
    lab     = "RND"
    staging = "STG"
    prod    = "PROD"
  }
}

variable "department" {
  description = "Department Owner"
  type        = string
  default     = "DEVOPS"
}

# --------------------------------------------------------------------------
#  Bucket Terraform State
# --------------------------------------------------------------------------
variable "tfstate_bucket" {
  description = "Name of bucket to store tfstate"
  type        = string
  default     = "tfo-tf-state-112233445566-ap-southeast-1"
}

variable "tfstate_dynamodb_table" {
  description = "Name of dynamodb table to store tfstate lock"
  type        = string
  default     = "tfo-ddb-tf-state-112233445566-ap-southeast-1"
}

variable "tfstate_path" {
  description = "Path .tfstate in Bucket"
  type        = string
  default     = "telemetryflow/112233445566/tfstate/terraform.tfstate"
}

variable "tfstate_encrypt" {
  description = "Encrypt tfstate at rest"
  type        = bool
  default     = true
}
