# ==========================================================================
#  Module EKS: _eks_var.tf (EKS-specific variables)
# --------------------------------------------------------------------------
#  Description:
#    Input Variable for EKS Cluster configuration
# --------------------------------------------------------------------------
#    - Prefix Resource Configuration
#    - Bucket Name
#    - DNS Zone
#    - EKS Cluster
#    - SSH Key Pair
#    - EKS Version
#    - Node Type / Storage / Counts
#    - EKS Addons Versions
# ==========================================================================

# --------------------------------------------------------------------------
#  Prefix Resource Configuration
# --------------------------------------------------------------------------
variable "prefix_name" {
  description = "Prefix to apply to all EKS resources"
  type        = string
  default     = "observability-tf"
}

# --------------------------------------------------------------------------
#  Bucket Name
# --------------------------------------------------------------------------
variable "bucket_name" {
  description = "S3 Bucket Name for EKS (logs / assets)"
  type        = string
}

# --------------------------------------------------------------------------
#  DNS (Public)
# --------------------------------------------------------------------------
variable "dns_zone" {
  description = "Route53 Hosted Zone ID used by the EKS cluster"
  type        = map(string)
}

variable "dns_url" {
  description = "DNS URL EKS per environment"
  type        = map(string)
}

# --------------------------------------------------------------------------
#  EKS Cluster
# --------------------------------------------------------------------------
variable "eks_cluster_name" {
  description = "Default cluster name"
  type        = string
}

variable "eks_name_env" {
  description = "Default EKS environment name suffix"
  type        = map(string)
  default = {
    lab     = "lab"
    staging = "staging"
    nonprod = "nonprod"
    prod    = "prod"
  }
}

# --------------------------------------------------------------------------
#  SSH configurations
# --------------------------------------------------------------------------
variable "ssh_key_pair" {
  description = "Default SSH keyname (pre-existing EC2 key pair)"
  type        = map(string)
}

# --------------------------------------------------------------------------
#  EKS Version (Default 1.35)
# --------------------------------------------------------------------------
variable "k8s_version" {
  description = "Default EKS version per environment"
  type        = map(string)
  default = {
    lab     = "1.35"
    staging = "1.35"
    prod    = "1.35"
  }
}

# --------------------------------------------------------------------------
#  Node Type / Storage (Default worker: t3.large)
# --------------------------------------------------------------------------
variable "eks_node_type" {
  description = "Default EKS worker node type per environment"
  type        = map(string)
  default = {
    lab     = "t3.large"
    staging = "t3.large"
    nonprod = "t3.large"
    prod    = "m5.large"
  }
}

variable "eks_node_storage" {
  description = "Default EKS worker node storage size in GB"
  type        = map(number)
  default = {
    lab     = 50
    staging = 50
    nonprod = 50
    prod    = 100
  }
}

variable "node_counts" {
  description = "Number of nodes for each role"
  type = object({
    worker     = number # Number of worker nodes (desired)
    worker_max = number # Maximum number of worker nodes
    worker_min = number # Minimum number of worker nodes
  })
  default = {
    worker     = 3
    worker_max = 10
    worker_min = 1
  }
}

# --------------------------------------------------------------------------
#  Pod Identity Agent Addon Version
# --------------------------------------------------------------------------
# aws eks describe-addon-versions \
#   --addon-name eks-pod-identity-agent \
#   --kubernetes-version 1.35 \
#   --query 'addons[0].addonVersions[*].addonVersion' \
#   --output table
variable "pod_identity_agent_version" {
  description = "Pod Identity Agent addon version per environment"
  type        = map(string)
  default = {
    lab     = "v1.4.0-eksbuild.1"
    staging = "v1.4.0-eksbuild.1"
    prod    = "v1.4.0-eksbuild.1"
  }
}

# --------------------------------------------------------------------------
#  EBS CSI Driver Version
# --------------------------------------------------------------------------
variable "ebs_csi_driver_version" {
  description = "EBS CSI driver version per environment"
  type        = map(string)
  default = {
    lab     = "v1.50.0-eksbuild.1"
    staging = "v1.50.0-eksbuild.1"
    prod    = "v1.50.0-eksbuild.1"
  }
}

# --------------------------------------------------------------------------
#  EFS CSI Driver Version
# --------------------------------------------------------------------------
variable "efs_csi_driver_version" {
  description = "EFS CSI driver version per environment"
  type        = map(string)
  default = {
    lab     = "v2.2.5-eksbuild.1"
    staging = "v2.2.5-eksbuild.1"
    prod    = "v2.2.5-eksbuild.1"
  }
}

# --------------------------------------------------------------------------
#  Kube Proxy Version
# --------------------------------------------------------------------------
variable "kube_proxy_version" {
  description = "Kube Proxy addon version per environment"
  type        = map(string)
  default = {
    lab     = "v1.35.1-eksbuild.1"
    staging = "v1.35.1-eksbuild.1"
    prod    = "v1.35.1-eksbuild.1"
  }
}

# --------------------------------------------------------------------------
#  Amazon VPC CNI Version
# --------------------------------------------------------------------------
variable "vpc_cni_version" {
  description = "Amazon VPC CNI addon version per environment"
  type        = map(string)
  default = {
    lab     = "v1.21.0-eksbuild.1"
    staging = "v1.21.0-eksbuild.1"
    prod    = "v1.21.0-eksbuild.1"
  }
}

# --------------------------------------------------------------------------
#  CoreDNS Version
# --------------------------------------------------------------------------
variable "coredns_version" {
  description = "CoreDNS addon version per environment"
  type        = map(string)
  default = {
    lab     = "v1.13.1-eksbuild.1"
    staging = "v1.13.1-eksbuild.1"
    prod    = "v1.13.1-eksbuild.1"
  }
}

# --------------------------------------------------------------------------
#  Snapshot Controller Version
# --------------------------------------------------------------------------
variable "snapshot_controller_version" {
  description = "Snapshot Controller addon version per environment"
  type        = map(string)
  default = {
    lab     = "v8.4.0-eksbuild.1"
    staging = "v8.4.0-eksbuild.1"
    prod    = "v8.4.0-eksbuild.1"
  }
}
