# ==========================================================================
#  Module Network: variable.tf
# --------------------------------------------------------------------------
#  Description:
#    Global & Core Infrastructure Variables
# --------------------------------------------------------------------------
#    - AWS Region
#    - AWS Account Profile
#    - Workspace Environment
#    - Core Prefix / CIDR / Subnet (a, b, c)
#    - IGW / NAT options
# ==========================================================================

# --------------------------------------------------------------------------
#  AWS
# --------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy the VPC in"
  type        = string
}

variable "aws_account_id_destination" {
  description = "The AWS Account ID to deploy resources in"
  type        = string
}

variable "aws_account_profile_destination" {
  description = "The AWS Profile to deploy resources in"
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

# --------------------------------------------------------------------------
#  Department Tags
# --------------------------------------------------------------------------
variable "department" {
  description = "Department Owner"
  type        = string
}

# --------------------------------------------------------------------------
#  Prefix Infra
# --------------------------------------------------------------------------
variable "coreinfra" {
  description = "Core Infrastructure Name Prefix"
  type        = string
}

# --------------------------------------------------------------------------
#  VPC
# --------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "Core Infrastructure CIDR Block"
  type        = map(string)
}

# --------------------------------------------------------------------------
#  Infra Prefix
# --------------------------------------------------------------------------
variable "ec2_prefix" {
  description = "EC2 Prefix Name"
  type        = string
}

variable "nat_ec2_prefix" {
  description = "NAT EC2 Prefix Name"
  type        = string
}

# --------------------------------------------------------------------------
#  Subnet - Private (a, b, c)
# --------------------------------------------------------------------------
variable "ec2_private_a" {
  description = "Private Subnet for EC2 Zone A"
  type        = map(string)
}

variable "ec2_private_b" {
  description = "Private Subnet for EC2 Zone B"
  type        = map(string)
}

variable "ec2_private_c" {
  description = "Private Subnet for EC2 Zone C"
  type        = map(string)
}

# --------------------------------------------------------------------------
#  Subnet - Public (a, b, c)
# --------------------------------------------------------------------------
variable "ec2_public_a" {
  description = "Public Subnet for EC2 Zone A"
  type        = map(string)
}

variable "ec2_public_b" {
  description = "Public Subnet for EC2 Zone B"
  type        = map(string)
}

variable "ec2_public_c" {
  description = "Public Subnet for EC2 Zone C"
  type        = map(string)
}

# --------------------------------------------------------------------------
#  Routing Table
# --------------------------------------------------------------------------
variable "ec2_rt_prefix" {
  description = "EC2 Routing Table Prefix Name"
  type        = string
}

# --------------------------------------------------------------------------
#  Internet Gateway
# --------------------------------------------------------------------------
variable "igw_prefix" {
  description = "IGW Prefix Name"
  type        = string
}

# --------------------------------------------------------------------------
#  NAT Gateway (optional)
# --------------------------------------------------------------------------
variable "enable_nat" {
  description = "Set to true to create a NAT Gateway serving private subnets (a, b, c)"
  type        = bool
  default     = false
}
