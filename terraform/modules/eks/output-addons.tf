# ==========================================================================
#  Module EKS: output-addons.tf (Output Terraform)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Return value eks module addons (CSI drivers + core addons)
# ==========================================================================

# --------------------------------------------------------------------------
#  Pod Identity Agent Addon
# --------------------------------------------------------------------------
output "pod_identity_agent_addon_arn" {
  description = "ARN of the Pod Identity Agent addon"
  value       = aws_eks_addon.pod_identity_agent.arn
}

# --------------------------------------------------------------------------
#  EBS CSI Driver Pod Identity Outputs
# --------------------------------------------------------------------------
output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_pod_identity_role.arn
}

output "ebs_csi_driver_policy_arn" {
  description = "ARN of the EBS CSI driver IAM policy"
  value       = aws_iam_policy.ebs_csi_driver_policy.arn
}

output "ebs_csi_pod_identity_association_arn" {
  description = "ARN of the EBS CSI driver pod identity association"
  value       = aws_eks_pod_identity_association.ebs_csi_driver.association_arn
}

output "ebs_csi_addon_arn" {
  description = "ARN of the EBS CSI driver addon"
  value       = aws_eks_addon.ebs_csi_driver.arn
}

# --------------------------------------------------------------------------
#  EFS CSI Driver Pod Identity Outputs
# --------------------------------------------------------------------------
output "efs_csi_driver_role_arn" {
  description = "ARN of the EFS CSI driver IAM role"
  value       = aws_iam_role.efs_csi_pod_identity_role.arn
}

output "efs_csi_driver_policy_arn" {
  description = "ARN of the EFS CSI driver IAM policy"
  value       = aws_iam_policy.efs_csi_driver_policy.arn
}

output "efs_csi_pod_identity_association_arn" {
  description = "ARN of the EFS CSI driver pod identity association"
  value       = aws_eks_pod_identity_association.efs_csi_driver.association_arn
}

output "efs_csi_addon_arn" {
  description = "ARN of the EFS CSI driver addon"
  value       = aws_eks_addon.efs_csi_driver.arn
}

# --------------------------------------------------------------------------
#  Core EKS Addons Outputs
# --------------------------------------------------------------------------
output "kube_proxy_addon_arn" {
  description = "ARN of the Kube Proxy addon"
  value       = aws_eks_addon.kube_proxy.arn
}

output "vpc_cni_addon_arn" {
  description = "ARN of the Amazon VPC CNI addon"
  value       = aws_eks_addon.vpc_cni.arn
}

output "coredns_addon_arn" {
  description = "ARN of the CoreDNS addon"
  value       = aws_eks_addon.coredns.arn
}

output "snapshot_controller_addon_arn" {
  description = "ARN of the Snapshot Controller addon"
  value       = aws_eks_addon.snapshot_controller.arn
}

# --------------------------------------------------------------------------
#  S3 Bucket
# --------------------------------------------------------------------------
output "eks_bucket_name" {
  description = "Name of the EKS S3 bucket"
  value       = local.bucket_name
}
