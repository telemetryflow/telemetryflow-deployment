# ==========================================================================
#  TelemetryFlow - TFO EC2: variable.tf
# --------------------------------------------------------------------------
#  Description:
#    Global Variable
# --------------------------------------------------------------------------
#    - AWS Region
#    - AWS Account ID
#    - AWS Account Profile
#    - Workspace Environment
#    - Global Tags
#    - Terraform State Backend references
#    - Compute configuration
# ==========================================================================

# --------------------------------------------------------------------------
#  AWS
# --------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_account_id_destination" {
  description = "The AWS Account ID to deploy resources in"
  type        = string
  default     = "112233445566"
}

variable "aws_account_profile_destination" {
  description = "The AWS Profile to deploy resources in"
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
#  Terraform State Backend references (for remote_states.tf)
# --------------------------------------------------------------------------
variable "tfstate_bucket" {
  description = "Name of bucket storing tfstate (from _tfstate stack)"
  type        = string
  default     = "tfo-tf-state-112233445566-ap-southeast-1"
}

variable "tfstate_dynamodb_table" {
  description = "Name of dynamodb table storing tfstate lock (from _tfstate stack)"
  type        = string
  default     = "tfo-ddb-tf-state-112233445566-ap-southeast-1"
}

variable "tfstate_path" {
  description = "Path .tfstate in Bucket (from _tfstate stack)"
  type        = string
  default     = "telemetryflow/112233445566/tfstate/terraform.tfstate"
}

# --------------------------------------------------------------------------
#  Compute configuration
# --------------------------------------------------------------------------
variable "prefix_name" {
  description = "Global Prefix Name for compute resources"
  type        = string
  default     = "tfo-ec2"
}

variable "node_pools" {
  description = <<EOT
Node pools keyed by pool name. Each pool defines count, instance type, RKE2
role, and root EBS storage. Instances are named "{prefix}-{pool}-{NN}".
EOT
  type = map(object({
    count                  = number
    instance_type          = string
    role                   = string
    root_volume_size       = number
    root_volume_type       = string
    root_volume_iops       = number
    root_volume_throughput = number
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
}

variable "ami_os" {
  description = "OS for the AMI: 'ubuntu' (24.04 LTS) or 'amazon_linux_2023'"
  type        = string
  default     = "ubuntu"
}

variable "use_spot_instances" {
  description = "Whether to use spot instances"
  type        = bool
  default     = false
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
  default     = "tfo-ssh-key"
}

variable "enable_nat" {
  description = "Set to true to create a NAT Gateway for the private subnet (zone-a)"
  type        = bool
  default     = false
}

# --------------------------------------------------------------------------
#  RKE2 Security Group (default on — required for RKE2/Rancher)
# --------------------------------------------------------------------------
variable "create_rke2_sg" {
  description = "Create the RKE2 cluster security group (API, etcd, kubelet, CNI, NodePort)"
  type        = bool
  default     = true
}

variable "rke2_api_access_cidrs" {
  description = "Extra CIDRs allowed to reach the Kubernetes API (6443) beyond the VPC. Example: [\"203.0.113.10/32\"]"
  type        = list(string)
  default     = []
}
