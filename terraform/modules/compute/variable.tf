# ==========================================================================
#  Module Compute: variable.tf
# --------------------------------------------------------------------------
#  Description:
#    Compute Variables
# --------------------------------------------------------------------------
#    - AWS / Workspace / Environment
#    - Prefix Name
#    - VPC / Subnet references
#    - Instance configuration (count, type, AMI, volume)
#    - Spot / Instance Connect options
# ==========================================================================

# --------------------------------------------------------------------------
#  AWS
# --------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "aws_account_profile_destination" {
  description = "The AWS Profile to deploy the Budget in"
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

variable "department" {
  description = "Department Owner"
  type        = string
}

# --------------------------------------------------------------------------
#  Global Prefix Name
# --------------------------------------------------------------------------
variable "prefix_name" {
  description = "Global Prefix Name"
  type        = string
}

# --------------------------------------------------------------------------
#  Compute Variables - Networking
# --------------------------------------------------------------------------
variable "vpc_id" {
  description = "VPC Id to deploy the EC2 instances"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID (zone-a) for instances with public IP"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID (zone-a) for instances without public IP"
  type        = string
}

# --------------------------------------------------------------------------
#  Compute Variables - Node Pools (master / worker)
# --------------------------------------------------------------------------
variable "node_pools" {
  description = <<EOT
Node pools keyed by pool name. Each pool defines its own count, instance type,
RKE2 role, and root EBS storage. Instances are named "{prefix}-{pool}-{NN}".

Default: 1 master (t3.medium, 30 GB) + 2 workers (m5.xlarge, 100 GB).
Set worker count to 3 for a 4-node cluster.
EOT
  type = map(object({
    count                  = number
    instance_type          = string
    role                   = string
    root_volume_size       = number # GB
    root_volume_type       = string # gp3 | gp2 | io2 | io1 | st1 | sc1 | standard
    root_volume_iops       = number # only for gp3 / io*
    root_volume_throughput = number # MB/s, only for gp3
  }))
  default = {
    master = {
      count                  = 1
      instance_type          = "t3.medium"
      role                   = "master"
      root_volume_size       = 30
      root_volume_type       = "gp3"
      root_volume_iops       = 3000
      root_volume_throughput = 125
    }
    worker = {
      count                  = 2
      instance_type          = "m5.xlarge"
      role                   = "worker"
      root_volume_size       = 100
      root_volume_type       = "gp3"
      root_volume_iops       = 6000
      root_volume_throughput = 250
    }
  }

  validation {
    condition     = alltrue([for _, p in var.node_pools : contains(["gp3", "gp2", "io2", "io1", "st1", "sc1", "standard"], p.root_volume_type)])
    error_message = "root_volume_type must be one of: gp3, gp2, io2, io1, st1, sc1, standard."
  }
}

variable "ami_os" {
  description = "OS for the AMI: 'ubuntu' (24.04 LTS) or 'amazon_linux_2023'"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = contains(["ubuntu", "amazon_linux_2023"], var.ami_os)
    error_message = "ami_os must be 'ubuntu' or 'amazon_linux_2023'."
  }
}

variable "use_spot_instances" {
  description = "Whether to use spot instances"
  type        = bool
  default     = false
}

variable "spot_price" {
  description = "Maximum spot price"
  type        = string
  default     = null
}

variable "create_instance_connect" {
  description = "Whether to create EC2 Instance Connect endpoint"
  type        = bool
  default     = true
}

variable "enable_access_public_ip" {
  description = "Set to true to place instances in the public subnet with a public IP"
  type        = bool
  default     = true
}

variable "key_pair_name" {
  description = "Name of the SSH key pair to use for the EC2 instances"
  type        = string
}

# --------------------------------------------------------------------------
#  RKE2 Security Group (default on — required for RKE2/Rancher)
# --------------------------------------------------------------------------
variable "create_rke2_sg" {
  description = "Create the RKE2 cluster security group (API, etcd, kubelet, CNI, NodePort). Set false for non-K8s workloads."
  type        = bool
  default     = true
}

variable "rke2_api_access_cidrs" {
  description = "Extra CIDRs allowed to reach the Kubernetes API (6443), in addition to the VPC CIDR. Example: [\"203.0.113.10/32\"] for your office IP."
  type        = list(string)
  default     = []
}
