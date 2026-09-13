# ==========================================================================
#  Module Compute: output.tf
# --------------------------------------------------------------------------
#  Description
#    Output Terraform Value
# --------------------------------------------------------------------------
#    - Launch Template
#    - AMI
#    - Instance Connect Endpoint
#    - Security Groups
#    - Instance IDs / IPs
# ==========================================================================

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.main.id
}

output "launch_template_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.main.latest_version
}

output "latest_ami_id" {
  description = "ID of the latest AMI being used"
  value       = local.selected_ami_id
}

output "instance_connect_endpoint_id" {
  description = "ID of the Instance Connect endpoint"
  value       = var.create_instance_connect ? aws_ec2_instance_connect_endpoint.main[0].id : null
}

output "instance_connect_endpoint_arn" {
  description = "ARN of the Instance Connect endpoint"
  value       = var.create_instance_connect ? aws_ec2_instance_connect_endpoint.main[0].arn : null
}

output "security_group_ec2_ids" {
  description = "IDs of the security groups applied to instances"
  value       = local.ec2_security_group_ids
}

output "security_group_rke2_id" {
  description = "ID of the RKE2 security group (null when create_rke2_sg=false)"
  value       = var.create_rke2_sg ? aws_security_group.rke2[0].id : null
}

output "instance_ids" {
  description = "Map of instance Name → instance ID"
  value = {
    for k, v in aws_instance.main : v.tags.Name => v.id
  }
}

output "instance_private_ips" {
  description = "Map of instance Name → private IP"
  value = {
    for k, v in aws_instance.main : v.tags.Name => v.private_ip
  }
}

output "instance_public_ips" {
  description = "Map of instance Name → public IP"
  value = {
    for k, v in aws_instance.main : v.tags.Name => v.public_ip
  }
}

output "nodes" {
  description = "Flat list of all nodes (name, role, pool, instance_id, private_ip, public_ip) — use for Ansible inventory generation"
  value = [
    for k, v in aws_instance.main : {
      name        = v.tags.Name
      role        = local.node_instances[k].role
      pool        = local.node_instances[k].pool_name
      instance_id = v.id
      private_ip  = v.private_ip
      public_ip   = v.public_ip
    }
  ]
}

output "nodes_by_pool" {
  description = "Map of pool name → list of instance Names"
  value = {
    for pool_name, pool in var.node_pools :
    pool_name => [
      for k, v in local.node_instances :
      v.name if v.pool_name == pool_name
    ]
  }
}
