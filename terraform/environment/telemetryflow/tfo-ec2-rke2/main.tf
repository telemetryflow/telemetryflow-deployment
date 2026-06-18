# ==========================================================================
#  TelemetryFlow - TFO EC2: main.tf
# --------------------------------------------------------------------------
#  Description:
#    Main Terraform Module - VPC + IGW + optional NAT + EC2 node pools (zone-a)
# --------------------------------------------------------------------------
#    - Workspace Environment
#    - Common Tags
#    - Module Network (VPC / Subnet a,b,c / IGW / NAT) - multi-AZ capable
#    - Module Compute (3 EC2 nodes placed in zone-a only)
# ==========================================================================

# --------------------------------------------------------------------------
#  Workspace Environment
# --------------------------------------------------------------------------
locals {
  env = terraform.workspace
}

# --------------------------------------------------------------------------
#  Global Tags
# --------------------------------------------------------------------------
locals {
  prefix_name    = var.prefix_name
  aws_account_id = var.aws_account_id_destination
  aws_region     = var.aws_region

  tags = {
    Environment     = "${var.environment[local.env]}"
    Department      = "${var.department}"
    DepartmentGroup = "${var.environment[local.env]}-${var.department}"
    Terraform       = true
  }

  # AZ in which the 3 EC2 nodes are placed (single-AZ deployment)
  node_az = "${var.aws_region}a"
}

# --------------------------------------------------------------------------
#  Reuse Module: Network (VPC + Subnet a,b,c + IGW + optional NAT)
# --------------------------------------------------------------------------
module "network" {
  source = "../../../modules//network"

  aws_region                      = var.aws_region
  aws_account_id_destination      = var.aws_account_id_destination
  aws_account_profile_destination = var.aws_account_profile_destination
  workspace_name                  = var.workspace_name
  workspace_env                   = var.workspace_env
  environment                     = var.environment
  department                      = var.department

  coreinfra      = var.coreinfra
  vpc_cidr       = var.vpc_cidr
  ec2_prefix     = var.ec2_prefix
  nat_ec2_prefix = var.nat_ec2_prefix

  ec2_private_a = var.ec2_private_a
  ec2_private_b = var.ec2_private_b
  ec2_private_c = var.ec2_private_c
  ec2_public_a  = var.ec2_public_a
  ec2_public_b  = var.ec2_public_b
  ec2_public_c  = var.ec2_public_c

  ec2_rt_prefix = var.ec2_rt_prefix
  igw_prefix    = var.igw_prefix
  enable_nat    = var.enable_nat
}

# --------------------------------------------------------------------------
#  Reuse Module: Compute (node pools in zone-a)
# --------------------------------------------------------------------------
module "compute" {
  source = "../../../modules//compute"

  aws_region                      = var.aws_region
  aws_account_profile_destination = var.aws_account_profile_destination
  workspace_name                  = var.workspace_name
  workspace_env                   = var.workspace_env
  environment                     = var.environment
  department                      = var.department

  prefix_name = var.prefix_name

  # All nodes are placed in zone-a (single-AZ) per requirement.
  # To spread across AZs, change these to 1b/1c and split the pools.
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  public_subnet_id  = module.network.ec2_public_1a
  private_subnet_id = module.network.ec2_private_1a

  node_pools              = var.node_pools
  ami_os                  = var.ami_os
  use_spot_instances      = var.use_spot_instances
  create_instance_connect = var.create_instance_connect
  enable_access_public_ip = var.enable_access_public_ip
  key_pair_name           = var.key_pair_name

  # RKE2 security group (on by default — required for the RKE2/Rancher cluster)
  create_rke2_sg        = var.create_rke2_sg
  rke2_api_access_cidrs = var.rke2_api_access_cidrs
}
