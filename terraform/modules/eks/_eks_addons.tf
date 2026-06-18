# ==========================================================================
#  Module EKS: _eks_addons.tf (EKS Addons Configuration)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Kube Proxy Addon
#    - Amazon VPC CNI Addon
#    - CoreDNS Addon
#    - Snapshot Controller Addon
# ==========================================================================

# --------------------------------------------------------------------------
#  Kube Proxy Addon
# --------------------------------------------------------------------------
resource "aws_eks_addon" "kube_proxy" {
  provider      = aws.destination
  cluster_name  = aws_eks_cluster.aws_eks.name
  addon_name    = "kube-proxy"
  addon_version = var.kube_proxy_version[local.env]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EKS-KUBE-PROXY-${upper(var.environment[local.env])}"
      Type            = "EKS-ADDON"
      ProductName     = "EKS-KUBE-PROXY"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Services        = "KUBE-PROXY"
    }
  )

  depends_on = [
    aws_eks_cluster.aws_eks,
    aws_eks_node_group.workers
  ]
}

# --------------------------------------------------------------------------
#  Amazon VPC CNI Addon
# --------------------------------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  provider      = aws.destination
  cluster_name  = aws_eks_cluster.aws_eks.name
  addon_name    = "vpc-cni"
  addon_version = var.vpc_cni_version[local.env]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EKS-VPC-CNI-${upper(var.environment[local.env])}"
      Type            = "EKS-ADDON"
      ProductName     = "EKS-VPC-CNI"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Services        = "VPC-CNI"
    }
  )

  depends_on = [
    aws_eks_cluster.aws_eks,
    aws_eks_node_group.workers
  ]
}

# --------------------------------------------------------------------------
#  CoreDNS Addon
# --------------------------------------------------------------------------
resource "aws_eks_addon" "coredns" {
  provider      = aws.destination
  cluster_name  = aws_eks_cluster.aws_eks.name
  addon_name    = "coredns"
  addon_version = var.coredns_version[local.env]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EKS-COREDNS-${upper(var.environment[local.env])}"
      Type            = "EKS-ADDON"
      ProductName     = "EKS-COREDNS"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Services        = "COREDNS"
    }
  )

  depends_on = [
    aws_eks_cluster.aws_eks,
    aws_eks_node_group.workers
  ]
}

# --------------------------------------------------------------------------
#  Snapshot Controller Addon
# --------------------------------------------------------------------------
resource "aws_eks_addon" "snapshot_controller" {
  provider      = aws.destination
  cluster_name  = aws_eks_cluster.aws_eks.name
  addon_name    = "snapshot-controller"
  addon_version = var.snapshot_controller_version[local.env]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EKS-SNAPSHOT-CONTROLLER-${upper(var.environment[local.env])}"
      Type            = "EKS-ADDON"
      ProductName     = "EKS-SNAPSHOT-CONTROLLER"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Services        = "SNAPSHOT-CONTROLLER"
    }
  )

  depends_on = [
    aws_eks_cluster.aws_eks,
    aws_eks_node_group.workers
  ]
}
