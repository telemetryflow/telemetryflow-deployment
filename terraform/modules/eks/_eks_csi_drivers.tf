# ==========================================================================
#  Module EKS: _eks_csi_drivers.tf (CSI Drivers with Pod Identity)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Pod Identity Agent Addon
#    - EBS CSI Driver with Pod Identity
#    - EFS CSI Driver with Pod Identity
# ==========================================================================

# --------------------------------------------------------------------------
#  Pod Identity Agent Addon (Required for Pod Identity)
# --------------------------------------------------------------------------
resource "aws_eks_addon" "pod_identity_agent" {
  provider      = aws.destination
  cluster_name  = aws_eks_cluster.aws_eks.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = var.pod_identity_agent_version[local.env]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EKS-POD-IDENTITY-${upper(var.environment[local.env])}"
      Type            = "EKS-ADDON"
      ProductName     = "EKS-POD-IDENTITY"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-ADDON" : "STG-EKS-ADDON"
      Services        = "POD-IDENTITY"
    }
  )

  depends_on = [
    aws_eks_cluster.aws_eks,
    aws_eks_node_group.workers
  ]
}

# --------------------------------------------------------------------------
#  EBS CSI Driver Pod Identity Association
# --------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  provider        = aws.destination
  cluster_name    = aws_eks_cluster.aws_eks.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_pod_identity_role.arn

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EBS-CSI-POD-IDENTITY-${upper(var.environment[local.env])}"
      Type            = "POD-IDENTITY"
      ProductName     = "EKS-EBS-CSI"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Services        = "EBS-CSI"
    }
  )

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role.ebs_csi_pod_identity_role
  ]
}

# --------------------------------------------------------------------------
#  EKS Add-on for EBS CSI Driver
# --------------------------------------------------------------------------
resource "aws_eks_addon" "ebs_csi_driver" {
  provider                    = aws.destination
  cluster_name                = aws_eks_cluster.aws_eks.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version[local.env]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_pod_identity_role.arn

  lifecycle {
    create_before_destroy = false
  }

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EBS-CSI-ADDON-${upper(var.environment[local.env])}"
      Type            = "EKS-ADDON"
      ProductName     = "EKS-EBS-CSI"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Services        = "EBS-CSI"
    }
  )

  depends_on = [
    aws_eks_pod_identity_association.ebs_csi_driver
  ]
}

# --------------------------------------------------------------------------
#  EFS CSI Driver Pod Identity Association
# --------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "efs_csi_driver" {
  provider        = aws.destination
  cluster_name    = aws_eks_cluster.aws_eks.name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi_pod_identity_role.arn

  lifecycle {
    create_before_destroy = false
  }

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EFS-CSI-POD-IDENTITY-${upper(var.environment[local.env])}"
      Type            = "POD-IDENTITY"
      ProductName     = "EKS-EFS-CSI"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Services        = "EFS-CSI"
    }
  )

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role.efs_csi_pod_identity_role
  ]
}

# --------------------------------------------------------------------------
#  EKS Add-on for EFS CSI Driver
# --------------------------------------------------------------------------
resource "aws_eks_addon" "efs_csi_driver" {
  provider                    = aws.destination
  cluster_name                = aws_eks_cluster.aws_eks.name
  addon_name                  = "aws-efs-csi-driver"
  addon_version               = var.efs_csi_driver_version[local.env]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.efs_csi_pod_identity_role.arn

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EFS-CSI-ADDON-${upper(var.environment[local.env])}"
      Type            = "EKS-ADDON"
      ProductName     = "EKS-EFS-CSI"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Services        = "EFS-CSI"
    }
  )

  depends_on = [
    aws_eks_pod_identity_association.efs_csi_driver
  ]
}
