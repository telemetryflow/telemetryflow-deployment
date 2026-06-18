# ==========================================================================
#  TelemetryFlow - TFO EKS: variable.tf
# --------------------------------------------------------------------------
#  Description:
#    Global Variable for the EKS observability stack
# --------------------------------------------------------------------------
#    - AWS Region / Account / Profile
#    - Workspace Environment
#    - Terraform State Backend references
#    - EKS cluster / node / addon configuration
# ==========================================================================

# --------------------------------------------------------------------------
#  AWS
# --------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy the EKS cluster in"
  type        = string
  default     = "ap-southeast-3"
}

variable "aws_account_id_destination" {
  description = "The AWS Account ID to deploy the EKS cluster in"
  type        = string
  default     = "112233445566"
}

variable "aws_account_profile_destination" {
  description = "The AWS Profile to deploy the EKS cluster in"
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
#  Terraform State Backend references (reads VPC/compute from tfo-ec2)
# --------------------------------------------------------------------------
variable "tfstate_bucket" {
  description = "Name of bucket storing the core tfstate (network + compute)"
  type        = string
  default     = "tfo-tf-state-112233445566-ap-southeast-3"
}

variable "tfstate_dynamodb_table" {
  description = "Name of DynamoDB table storing the core tfstate lock"
  type        = string
  default     = "tfo-ddb-tf-state-112233445566-ap-southeast-3"
}

variable "tfstate_path" {
  description = "Path to the core .tfstate in the bucket"
  type        = string
  default     = "telemetryflow/112233445566/tfo-ec2/terraform.tfstate"
}

# --------------------------------------------------------------------------
#  EKS Cluster
# --------------------------------------------------------------------------
variable "prefix_name" {
  description = "Global Prefix Name for EKS resources"
  type        = string
  default     = "observability-tf"
}

variable "eks_cluster_name" {
  description = "EKS cluster name (environment suffix is appended)"
  type        = string
  default     = "tfo-eks"
}

variable "eks_name_env" {
  description = "EKS environment suffix per workspace"
  type        = map(string)
  default = {
    default = "staging"
    lab     = "lab"
    staging = "staging"
    prod    = "prod"
  }
}

variable "bucket_name" {
  description = "S3 bucket name for EKS (environment suffix is appended)"
  type        = string
  default     = "tfo-eks-bucket"
}

variable "kms_key" {
  description = "KMS key alias per workspace (existing CMK)"
  type        = map(string)
  default = {
    default = "alias/aws/s3"
    lab     = "alias/aws/s3"
    staging = "alias/aws/s3"
    prod    = "alias/aws/s3"
  }
}

variable "dns_zone" {
  description = "Route53 Hosted Zone ID per workspace (for cert-manager DNS validation)"
  type        = map(string)
  default = {
    default = "Z000000000000ABCDEF000"
    lab     = "Z000000000000ABCDEF000"
    staging = "Z000000000000ABCDEF000"
    prod    = "Z000000000000ABCDEF000"
  }
}

variable "dns_url" {
  description = "DNS URL per workspace"
  type        = map(string)
  default = {
    default = "staging.telemetryflow.eks"
    lab     = "lab.telemetryflow.eks"
    staging = "staging.telemetryflow.eks"
    prod    = "telemetryflow.eks"
  }
}

# --------------------------------------------------------------------------
#  SSH Key Pair (pre-existing EC2 key pair per workspace)
# --------------------------------------------------------------------------
variable "ssh_key_pair" {
  description = "SSH key pair name per workspace"
  type        = map(string)
  default = {
    default = "tfo-ssh-key"
    lab     = "tfo-ssh-key"
    staging = "tfo-ssh-key"
    prod    = "tfo-ssh-key"
  }
}

# --------------------------------------------------------------------------
#  Node Group (default 3x t3.large worker)
# --------------------------------------------------------------------------
variable "k8s_version" {
  description = "EKS version per workspace"
  type        = map(string)
  default = {
    default = "1.35"
    lab     = "1.35"
    staging = "1.35"
    prod    = "1.35"
  }
}

variable "eks_node_type" {
  description = "Worker node instance type per workspace"
  type        = map(string)
  default = {
    default = "t3.large"
    lab     = "t3.large"
    staging = "t3.large"
    prod    = "m5.large"
  }
}

variable "eks_node_storage" {
  description = "Worker node disk size (GB) per workspace"
  type        = map(number)
  default = {
    default = 50
    lab     = 50
    staging = 50
    prod    = 100
  }
}

variable "node_counts" {
  description = "Worker node scaling (desired / max / min)"
  type = object({
    worker     = number
    worker_max = number
    worker_min = number
  })
  default = {
    worker     = 3
    worker_max = 10
    worker_min = 1
  }
}

# --------------------------------------------------------------------------
#  EKS Addons (latest for 1.35 — see modules/eks/LIST-ADDONS.md)
# --------------------------------------------------------------------------
variable "pod_identity_agent_version" {
  description = "eks-pod-identity-agent version per workspace"
  type        = map(string)
  default = {
    default = "v1.4.0-eksbuild.1"
    lab     = "v1.4.0-eksbuild.1"
    staging = "v1.4.0-eksbuild.1"
    prod    = "v1.4.0-eksbuild.1"
  }
}

variable "ebs_csi_driver_version" {
  description = "aws-ebs-csi-driver version per workspace"
  type        = map(string)
  default = {
    default = "v1.50.0-eksbuild.1"
    lab     = "v1.50.0-eksbuild.1"
    staging = "v1.50.0-eksbuild.1"
    prod    = "v1.50.0-eksbuild.1"
  }
}

variable "efs_csi_driver_version" {
  description = "aws-efs-csi-driver version per workspace"
  type        = map(string)
  default = {
    default = "v2.2.5-eksbuild.1"
    lab     = "v2.2.5-eksbuild.1"
    staging = "v2.2.5-eksbuild.1"
    prod    = "v2.2.5-eksbuild.1"
  }
}

variable "kube_proxy_version" {
  description = "kube-proxy version per workspace"
  type        = map(string)
  default = {
    default = "v1.35.1-eksbuild.1"
    lab     = "v1.35.1-eksbuild.1"
    staging = "v1.35.1-eksbuild.1"
    prod    = "v1.35.1-eksbuild.1"
  }
}

variable "vpc_cni_version" {
  description = "vpc-cni version per workspace"
  type        = map(string)
  default = {
    default = "v1.21.0-eksbuild.1"
    lab     = "v1.21.0-eksbuild.1"
    staging = "v1.21.0-eksbuild.1"
    prod    = "v1.21.0-eksbuild.1"
  }
}

variable "coredns_version" {
  description = "coredns version per workspace"
  type        = map(string)
  default = {
    default = "v1.13.1-eksbuild.1"
    lab     = "v1.13.1-eksbuild.1"
    staging = "v1.13.1-eksbuild.1"
    prod    = "v1.13.1-eksbuild.1"
  }
}

variable "snapshot_controller_version" {
  description = "snapshot-controller version per workspace"
  type        = map(string)
  default = {
    default = "v8.4.0-eksbuild.1"
    lab     = "v8.4.0-eksbuild.1"
    staging = "v8.4.0-eksbuild.1"
    prod    = "v8.4.0-eksbuild.1"
  }
}
