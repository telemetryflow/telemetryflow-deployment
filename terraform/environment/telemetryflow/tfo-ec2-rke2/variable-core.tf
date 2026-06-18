# ==========================================================================
#  TelemetryFlow - TFO EC2: variable-core.tf
# --------------------------------------------------------------------------
#  Description
#    Core Infrastructure (network) specific variables - multi AZ (a, b, c)
# --------------------------------------------------------------------------
#    - Core Prefix Name
#    - Core VPC CIDR Block
#    - Core Prefix EC2
#    - Core Prefix NAT EC2
#    - Subnet CIDR (a, b, c)
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
#  Subnet - Private (a, b, c)
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

variable "ec2_private_b" {
  description = "Private Subnet for EC2 Zone B"
  type        = map(string)
  default = {
    default = "10.40.72.0/21"
    lab     = "10.40.72.0/21"
    staging = "10.41.72.0/21"
    prod    = "10.42.72.0/21"
  }
}

variable "ec2_private_c" {
  description = "Private Subnet for EC2 Zone C"
  type        = map(string)
  default = {
    default = "10.40.80.0/21"
    lab     = "10.40.80.0/21"
    staging = "10.41.80.0/21"
    prod    = "10.42.80.0/21"
  }
}

# --------------------------------------------------------------------------
#  Subnet - Public (a, b, c)
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

variable "ec2_public_b" {
  description = "Public Subnet for EC2 Zone B"
  type        = map(string)
  default = {
    default = "10.40.96.0/21"
    lab     = "10.40.96.0/21"
    staging = "10.41.96.0/21"
    prod    = "10.42.96.0/21"
  }
}

variable "ec2_public_c" {
  description = "Public Subnet for EC2 Zone C"
  type        = map(string)
  default = {
    default = "10.40.104.0/21"
    lab     = "10.40.104.0/21"
    staging = "10.41.104.0/21"
    prod    = "10.42.104.0/21"
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
