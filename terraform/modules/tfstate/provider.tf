# ==========================================================================
#  Module TFState: provider.tf
# --------------------------------------------------------------------------
#  Description:
#    Provider Modules
# --------------------------------------------------------------------------
#    - Terraform Cli Version
#    - AWS Terraform Version
#    - AWS Region
# ==========================================================================

# --------------------------------------------------------------------------
#  Terraform AWS Version Compatibility
# --------------------------------------------------------------------------
terraform {
  required_version = ">= 1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.72"
    }

    random = ">= 2.0"
  }
}

# --------------------------------------------------------------------------
#  AWS Provider Properties
# --------------------------------------------------------------------------
provider "aws" {
  alias   = "destination"
  region  = var.aws_region
  profile = var.aws_account_profile_destination

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment[local.env]
      Department  = var.department
    }
  }
}
