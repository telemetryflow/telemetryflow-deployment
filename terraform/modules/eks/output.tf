# ==========================================================================
#  Module EKS: output.tf (Output Terraform)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Return value eks module
# ==========================================================================

# --------------------------------------------------------------------------
#  EKS VPC
# --------------------------------------------------------------------------
output "eks_vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  value       = data.aws_vpc.selected.id
}

# --------------------------------------------------------------------------
#  EKS Cluster Name
# --------------------------------------------------------------------------
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.aws_eks.name
}

# --------------------------------------------------------------------------
#  EKS Cluster Endpoint
# --------------------------------------------------------------------------
output "eks_cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.aws_eks.endpoint
}

# --------------------------------------------------------------------------
#  EKS Cluster Certificate Authority
# --------------------------------------------------------------------------
output "eks_cluster_certificate_authority" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.aws_eks.certificate_authority
}

# --------------------------------------------------------------------------
#  EKS Security Group
# --------------------------------------------------------------------------
output "eks_security_group" {
  description = "EKS security group ID"
  value       = aws_security_group.eks_sg.id
}

# --------------------------------------------------------------------------
#  EKS Node Group (workers)
# --------------------------------------------------------------------------
output "eks_nodegroup_workers_id" {
  description = "EKS worker node group ID"
  value       = aws_eks_node_group.workers.id
}

output "eks_nodegroup_workers_arn" {
  description = "EKS worker node group ARN"
  value       = aws_eks_node_group.workers.arn
}

output "eks_nodegroup_workers_status" {
  description = "EKS worker node group status"
  value       = aws_eks_node_group.workers.status
}

# --------------------------------------------------------------------------
#  IAM Roles
# --------------------------------------------------------------------------
output "eks_cluster_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_nodes_role_arn" {
  description = "IAM role ARN of the EKS worker nodes"
  value       = aws_iam_role.eks_nodes.arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for cluster-autoscaler (OIDC)"
  value       = aws_iam_role.cluster_autoscaler_role.arn
}

# --------------------------------------------------------------------------
#  OIDC
# --------------------------------------------------------------------------
output "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "eks_oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  value       = aws_iam_openid_connect_provider.cluster.url
}

# --------------------------------------------------------------------------
#  EKS Config Map Auth & Kube Config
# --------------------------------------------------------------------------
output "config_map_aws_auth" {
  description = "aws-auth ConfigMap body for the EKS cluster"
  value       = local.config_map_aws_auth
}

output "kubeconfig" {
  description = "kubeconfig body for the EKS cluster"
  value       = local.kubeconfig
}
