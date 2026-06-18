# ==========================================================================
#  TelemetryFlow - TFO EKS: main.tf
# --------------------------------------------------------------------------
#  Description:
#    EKS observability cluster (1.35) wired from the network/compute stack.
# --------------------------------------------------------------------------
#    - Workspace Environment
#    - Common Tags
#    - Module EKS (Cluster / Nodes / Addons / CSI / IAM / SG / S3)
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
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id_destination

  tags = {
    Environment     = var.environment[local.env]
    Department      = var.department
    DepartmentGroup = "${var.environment[local.env]}-${var.department}"
    Terraform       = true
  }
}

# --------------------------------------------------------------------------
#  Reuse Module: EKS (observability cluster)
# --------------------------------------------------------------------------
module "eks" {
  source = "../../../modules//eks"

  aws_region                      = var.aws_region
  aws_account_id_destination      = var.aws_account_id_destination
  aws_account_profile_destination = var.aws_account_profile_destination
  workspace_name                  = var.workspace_name
  workspace_env                   = var.workspace_env
  environment                     = var.environment
  department                      = var.department

  # Core state backend (reads VPC / subnet / SG from tfo-ec2)
  tfstate_bucket         = var.tfstate_bucket
  tfstate_dynamodb_table = var.tfstate_dynamodb_table
  tfstate_path           = var.tfstate_path

  # EKS cluster
  prefix_name      = var.prefix_name
  eks_cluster_name = var.eks_cluster_name
  eks_name_env     = var.eks_name_env
  bucket_name      = var.bucket_name

  kms_key = var.kms_key

  dns_zone = var.dns_zone
  dns_url  = var.dns_url

  # Node group (default 3x t3.large)
  k8s_version      = var.k8s_version
  eks_node_type    = var.eks_node_type
  eks_node_storage = var.eks_node_storage
  node_counts      = var.node_counts
  ssh_key_pair     = var.ssh_key_pair

  # EKS Addons
  pod_identity_agent_version  = var.pod_identity_agent_version
  ebs_csi_driver_version      = var.ebs_csi_driver_version
  efs_csi_driver_version      = var.efs_csi_driver_version
  kube_proxy_version          = var.kube_proxy_version
  vpc_cni_version             = var.vpc_cni_version
  coredns_version             = var.coredns_version
  snapshot_controller_version = var.snapshot_controller_version
}
