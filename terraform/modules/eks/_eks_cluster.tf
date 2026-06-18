# ==========================================================================
#  Module EKS: _eks_cluster.tf (Cluster Configuration)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - EKS Cluster Name
#    - EKS Version
#    - Cluster VPC Subnet
#    - Cluster Tagging
# ==========================================================================

# --------------------------------------------------------------------------
#  Resources Tags
# --------------------------------------------------------------------------
locals {
  resources_tags = {
    Name          = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}"
    ResourceGroup = "${var.environment[local.env]}-EKS-TFO"
  }
}

# --------------------------------------------------------------------------
#  EKS Output Config Auth & KubeConfig
# --------------------------------------------------------------------------
locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks_nodes.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH

  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.aws_eks.certificate_authority.0.data}
    server: ${aws_eks_cluster.aws_eks.endpoint}
  name: ${aws_eks_cluster.aws_eks.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.aws_eks.arn}
    user: ${aws_eks_cluster.aws_eks.arn}
  name: ${aws_eks_cluster.aws_eks.arn}
current-context: ${aws_eks_cluster.aws_eks.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.aws_eks.arn}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
        - "--region"
        - "${var.aws_region}"
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "${aws_eks_cluster.aws_eks.name}"
      command: aws
KUBECONFIG
}

# --------------------------------------------------------------------------
#  VPC EKS (from remote state)
# --------------------------------------------------------------------------
data "aws_vpc" "selected" {
  id = data.terraform_remote_state.core_state.outputs.vpc_id
}

# --------------------------------------------------------------------------
#  EKS Cluster
# --------------------------------------------------------------------------
resource "aws_eks_cluster" "aws_eks" {
  provider                  = aws.destination
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  name                      = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}"
  role_arn                  = aws_iam_role.eks_cluster.arn
  version                   = var.k8s_version[local.env]

  vpc_config {
    subnet_ids = [
      data.terraform_remote_state.core_state.outputs.ec2_private_1a[0],
      data.terraform_remote_state.core_state.outputs.ec2_private_1b[0],
      data.terraform_remote_state.core_state.outputs.ec2_private_1c[0],
      data.terraform_remote_state.core_state.outputs.ec2_public_1a[0],
      data.terraform_remote_state.core_state.outputs.ec2_public_1b[0],
      data.terraform_remote_state.core_state.outputs.ec2_public_1c[0]
    ]
  }

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      "ClusterName"                                                                      = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}"
      "k8s.io/cluster-autoscaler/${var.eks_cluster_name}-${var.eks_name_env[local.env]}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"                                                = "true"
    },
    {
      Environment     = upper(var.environment[local.env])
      Name            = "EKS-${var.k8s_version[local.env]}-${upper(var.eks_cluster_name)}-${upper(var.environment[local.env])}"
      Type            = "PRODUCTS"
      ProductName     = "EKS-TFO"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-TFO" : "STG-EKS-TFO"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-TFO" : "STG-EKS-TFO"
      Services        = "EKS"
    }
  )
}

locals {
  eks_oidc_thumbprint = data.tls_certificate.cluster.certificates.0.sha1_fingerprint
}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.aws_eks.identity.0.oidc.0.issuer
}

data "aws_availability_zones" "available" {
  state = "available"
}

# --------------------------------------------------------------------------
#  OIDC config
# --------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "cluster" {
  provider        = aws.destination
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [local.eks_oidc_thumbprint]
  url             = aws_eks_cluster.aws_eks.identity.0.oidc.0.issuer
}
