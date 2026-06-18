# ==========================================================================
#  Module EKS: provider.tf
# --------------------------------------------------------------------------
#  Description:
#    Provider Modules
# --------------------------------------------------------------------------
#    - Terraform Cli Version
#    - AWS Terraform Version
#    - AWS Region / Profile
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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.0"
    }

    random = ">= 2.0"
  }
}

# --------------------------------------------------------------------------
#  AWS Provider Properties (destination account)
# --------------------------------------------------------------------------
provider "aws" {
  alias   = "destination"
  region  = var.aws_region
  profile = var.aws_account_profile_destination
}
