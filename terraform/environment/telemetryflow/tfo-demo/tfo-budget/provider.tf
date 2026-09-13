# ==========================================================================
#  TelemetryFlow - TFO Budget: provider.tf
# --------------------------------------------------------------------------
#  Description:
#    Terraform & AWS Provider configuration
# ==========================================================================

terraform {
  required_version = ">= 1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.72"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_account_profile_destination

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = "TelemetryFlow"
      Environment = terraform.workspace
    }
  }
}
