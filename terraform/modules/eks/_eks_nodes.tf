# ==========================================================================
#  Module EKS: _eks_nodes.tf (EKS Node Group Configuration)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - EKS Node Group Name
#    - EKS Version
#    - SSH Key
#    - Node VPC Subnet
#    - Node Scaling (default 3x t3.large worker)
#    - Node Tagging
# ==========================================================================

# ============================================
# NODE GROUP - WORKERS (observability)
# ============================================
locals {
  node_selector_tfo = "tfo"
}

resource "aws_eks_node_group" "workers" {
  provider = aws.destination

  cluster_name    = aws_eks_cluster.aws_eks.name
  node_group_name = "${local.node_selector_tfo}-worker-node"
  node_role_arn   = aws_iam_role.eks_nodes.arn

  ## EKS Private Subnets ###
  subnet_ids = [
    data.terraform_remote_state.core_state.outputs.ec2_private_1a[0],
    data.terraform_remote_state.core_state.outputs.ec2_private_1b[0],
    data.terraform_remote_state.core_state.outputs.ec2_private_1c[0]
  ]

  instance_types = [var.eks_node_type[local.env]]
  disk_size      = var.eks_node_storage[local.env]
  version        = var.k8s_version[local.env]

  labels = {
    "environment" = var.eks_name_env[local.env]
    "node"        = "${local.node_selector_tfo}-worker"
    "department"  = lower(var.department)
    "productname" = "${local.node_selector_tfo}-worker"
    "service"     = "observability"
  }

  remote_access {
    ec2_ssh_key = var.ssh_key_pair[local.env]
  }

  scaling_config {
    desired_size = var.node_counts.worker
    max_size     = var.node_counts.worker_max
    min_size     = var.node_counts.worker_min
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size,
      scaling_config[0].min_size,
    ]
  }

  tags = merge(
    {
      "ClusterName"                                               = aws_eks_cluster.aws_eks.name
      "k8s.io/cluster-autoscaler/${aws_eks_cluster.aws_eks.name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"                         = "true"
      "Terraform"                                                 = "true"
    },
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EKS-${var.k8s_version[local.env]}-${upper(local.node_selector_tfo)}-WORKER"
      Type            = "PRODUCTS"
      ProductName     = "EKS-TFO"
      ProductGroup    = "${upper(var.environment[local.env])}-EKS-TFO"
      Department      = var.department
      DepartmentGroup = "${upper(var.environment[local.env])}-${var.department}"
      ResourceGroup   = "${upper(var.environment[local.env])}-EKS-TFO"
      Services        = "OBSERVABILITY"
    }
  )

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_iam_worker_node_policy,
    aws_iam_role_policy_attachment.eks_iam_cni_policy,
    aws_iam_role_policy_attachment.eks_iam_container_registry_policy,
  ]
}

# --------------------------------------------------------------------------
#  Node Group Output
# --------------------------------------------------------------------------
output "eks_node_name_workers" {
  value = aws_eks_node_group.workers.id
}
