# ==========================================================================
#  Module Network: output.tf
# --------------------------------------------------------------------------
#  Description
#    Output Terraform Value
# --------------------------------------------------------------------------
#    - VPC ID / CIDR / Name
#    - VPC Security Group ID
#    - Subnet ID / CIDR (Private a, b, c)
#    - Subnet ID / CIDR (Public a, b, c)
#    - NAT Gateway / EIP (when enabled)
# ==========================================================================

# --------------------------------------------------------------------------
#  VPC Output
# --------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC Identity"
  value       = aws_vpc.infra_vpc.id
}

output "vpc_cidr" {
  description = "VPC CIDR Block"
  value       = aws_vpc.infra_vpc.cidr_block
}

output "vpc_name" {
  description = "VPC Name"
  value       = local.vpc_tags.Name
}

output "security_group_id" {
  description = "Security Group of VPC Id's"
  value       = aws_security_group.default.id
}

# --------------------------------------------------------------------------
#  EC2 Output - Private (a, b, c)
# --------------------------------------------------------------------------
output "ec2_private_1a" {
  description = "Private Subnet EC2 Zone A"
  value       = aws_subnet.ec2_private_a.id
}

output "ec2_private_1a_cidr" {
  description = "Private Subnet EC2 CIDR Block of Zone A"
  value       = aws_subnet.ec2_private_a.cidr_block
}

output "ec2_private_1b" {
  description = "Private Subnet EC2 Zone B"
  value       = aws_subnet.ec2_private_b.id
}

output "ec2_private_1b_cidr" {
  description = "Private Subnet EC2 CIDR Block of Zone B"
  value       = aws_subnet.ec2_private_b.cidr_block
}

output "ec2_private_1c" {
  description = "Private Subnet EC2 Zone C"
  value       = aws_subnet.ec2_private_c.id
}

output "ec2_private_1c_cidr" {
  description = "Private Subnet EC2 CIDR Block of Zone C"
  value       = aws_subnet.ec2_private_c.cidr_block
}

# --------------------------------------------------------------------------
#  EC2 Output - Public (a, b, c)
# --------------------------------------------------------------------------
output "ec2_public_1a" {
  description = "Public Subnet EC2 Zone A"
  value       = aws_subnet.ec2_public_a.id
}

output "ec2_public_1a_cidr" {
  description = "Public Subnet EC2 CIDR Block of Zone A"
  value       = aws_subnet.ec2_public_a.cidr_block
}

output "ec2_public_1b" {
  description = "Public Subnet EC2 Zone B"
  value       = aws_subnet.ec2_public_b.id
}

output "ec2_public_1b_cidr" {
  description = "Public Subnet EC2 CIDR Block of Zone B"
  value       = aws_subnet.ec2_public_b.cidr_block
}

output "ec2_public_1c" {
  description = "Public Subnet EC2 Zone C"
  value       = aws_subnet.ec2_public_c.id
}

output "ec2_public_1c_cidr" {
  description = "Public Subnet EC2 CIDR Block of Zone C"
  value       = aws_subnet.ec2_public_c.cidr_block
}

# --------------------------------------------------------------------------
#  NAT Output (when enabled)
# --------------------------------------------------------------------------
output "nat_gateway_id" {
  description = "NAT Gateway ID (zone-a) if enabled"
  value       = var.enable_nat ? aws_nat_gateway.ec2_ngw[0].id : null
}

output "nat_eip" {
  description = "NAT Gateway Elastic IP (zone-a) if enabled"
  value       = var.enable_nat ? aws_eip.ec2[0].public_ip : null
}

# --------------------------------------------------------------------------
#  Summary Output
# --------------------------------------------------------------------------
locals {
  summary = <<SUMMARY
VPC Summary (multi-AZ a, b, c):
  VPC Id:            ${aws_vpc.infra_vpc.id}
  Security Group Id: ${aws_security_group.default.id}
Subnet Private:
  EC2 Private 1a:    ${aws_subnet.ec2_private_a.id}
  EC2 Private 1b:    ${aws_subnet.ec2_private_b.id}
  EC2 Private 1c:    ${aws_subnet.ec2_private_c.id}
Subnet Public:
  EC2 Public 1a:     ${aws_subnet.ec2_public_a.id}
  EC2 Public 1b:     ${aws_subnet.ec2_public_b.id}
  EC2 Public 1c:     ${aws_subnet.ec2_public_c.id}
CIDR Block Private:
  EC2 CIDR 1a:       ${aws_subnet.ec2_private_a.cidr_block}
  EC2 CIDR 1b:       ${aws_subnet.ec2_private_b.cidr_block}
  EC2 CIDR 1c:       ${aws_subnet.ec2_private_c.cidr_block}
CIDR Block Public:
  EC2 CIDR 1a:       ${aws_subnet.ec2_public_a.cidr_block}
  EC2 CIDR 1b:       ${aws_subnet.ec2_public_b.cidr_block}
  EC2 CIDR 1c:       ${aws_subnet.ec2_public_c.cidr_block}
NAT Gateway:         ${var.enable_nat ? "enabled" : "disabled"}
SUMMARY
}

output "summary" {
  description = "Summary Core Infrastructure Configuration"
  value       = local.summary
}
