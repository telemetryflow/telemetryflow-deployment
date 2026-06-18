# ==========================================================================
#  Module Network: vpc.tf
# --------------------------------------------------------------------------
#  Description
#    VPC Main
# --------------------------------------------------------------------------
#    - VPC Identity
#    - VPC Tags
# ==========================================================================

# --------------------------------------------------------------------------
#  VPC Tags
# --------------------------------------------------------------------------
locals {
  vpc_tags = {
    ResourceGroup = "${var.environment[local.env]}-VPC"
    Name          = "${var.coreinfra}-${var.workspace_env[local.env]}-vpc"
  }
}

# --------------------------------------------------------------------------
#  VPC Identity
# --------------------------------------------------------------------------
resource "aws_vpc" "infra_vpc" {
  provider = aws.destination

  cidr_block           = var.vpc_cidr[local.env]
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags     = merge(local.tags, local.vpc_tags)
  tags_all = merge(local.tags, local.vpc_tags)
}
