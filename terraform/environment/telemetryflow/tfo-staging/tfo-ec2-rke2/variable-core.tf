# ==========================================================================
#  TelemetryFlow - TFO EC2: variable-core.tf
# --------------------------------------------------------------------------
#  Description
#    Core Infrastructure (network) specific variables - single AZ (a)
# --------------------------------------------------------------------------
#    - Core Prefix Name
#    - Core VPC CIDR Block
#    - Core Prefix EC2
#    - Core Prefix NAT EC2
#    - Subnet CIDR (a)
#    - Routing Table / IGW Prefix
# ==========================================================================

# --------------------------------------------------------------------------
#  Prefix Infra
# --------------------------------------------------------------------------
variable "coreinfra" {
  description = "Core Infrastructure Name Prefix"
  type        = string
  default     = "core-ec2-tf"
}

# --------------------------------------------------------------------------
#  VPC
# --------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "Core Infrastructure CIDR Block"
  type        = map(string)
  default = {
    default = "10.40.0.0/16"
    lab     = "10.40.0.0/16"
    staging = "10.41.0.0/16"
    prod    = "10.42.0.0/16"
  }
}

# --------------------------------------------------------------------------
#  Infra Prefix
# --------------------------------------------------------------------------
variable "ec2_prefix" {
  description = "EC2 Prefix Name"
  type        = string
  default     = "ec2"
}

variable "nat_ec2_prefix" {
  description = "NAT EC2 Prefix Name"
  type        = string
  default     = "natgw-ec2"
}

# --------------------------------------------------------------------------
#  Subnet - Private (a)
# --------------------------------------------------------------------------
variable "ec2_private_a" {
  description = "Private Subnet for EC2 Zone A"
  type        = map(string)
  default = {
    default = "10.40.64.0/21"
    lab     = "10.40.64.0/21"
    staging = "10.41.64.0/21"
    prod    = "10.42.64.0/21"
  }
}

# --------------------------------------------------------------------------
#  Subnet - Public (a)
# --------------------------------------------------------------------------
variable "ec2_public_a" {
  description = "Public Subnet for EC2 Zone A"
  type        = map(string)
  default = {
    default = "10.40.88.0/21"
    lab     = "10.40.88.0/21"
    staging = "10.41.88.0/21"
    prod    = "10.42.88.0/21"
  }
}

# --------------------------------------------------------------------------
#  Routing Table
# --------------------------------------------------------------------------
variable "ec2_rt_prefix" {
  description = "EC2 Routing Table Prefix Name"
  type        = string
  default     = "ec2-rt"
}

# --------------------------------------------------------------------------
#  Internet Gateway
# --------------------------------------------------------------------------
variable "igw_prefix" {
  description = "IGW Prefix Name"
  type        = string
  default     = "igw"
}
