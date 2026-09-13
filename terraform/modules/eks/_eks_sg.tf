# ==========================================================================
#  Module EKS: _eks_sg.tf (Security Group Configuration)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - SSH Port
#    - TelemetryFlow service ports (PostgreSQL, Redis, OTLP, Webapp)
#    - Node-to-node all
#    - Egress
# ==========================================================================

resource "aws_security_group" "eks_sg" {
  provider    = aws.destination
  name        = "${var.eks_cluster_name}-eks-${var.eks_name_env[local.env]}-sg"
  description = "${var.eks_cluster_name}-eks-${var.eks_name_env[local.env]} security groups"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH Port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      data.terraform_remote_state.core_state.outputs.ec2_private_1a_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1b_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1c_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_public_1a_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_public_1b_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_public_1c_cidr
    ]
    ipv6_cidr_blocks = ["::/0"]
    security_groups = [
      data.terraform_remote_state.core_state.outputs.security_group_id
    ]
  }

  ingress {
    description = "PostgreSQL Port"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [
      data.terraform_remote_state.core_state.outputs.ec2_private_1a_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1b_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1c_cidr
    ]
    ipv6_cidr_blocks = ["::/0"]
    security_groups = [
      data.terraform_remote_state.core_state.outputs.security_group_id
    ]
  }

  ingress {
    description = "Redis Port"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [
      data.terraform_remote_state.core_state.outputs.ec2_private_1a_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1b_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1c_cidr
    ]
    ipv6_cidr_blocks = ["::/0"]
    security_groups = [
      data.terraform_remote_state.core_state.outputs.security_group_id
    ]
  }

  ingress {
    description = "OTLP gRPC (Collector)"
    from_port   = 4317
    to_port     = 4317
    protocol    = "tcp"
    cidr_blocks = [
      data.terraform_remote_state.core_state.outputs.ec2_private_1a_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1b_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1c_cidr
    ]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "OTLP HTTP (Collector)"
    from_port   = 4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = [
      data.terraform_remote_state.core_state.outputs.ec2_private_1a_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1b_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1c_cidr
    ]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Webapp Port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Webapp Port 8000-9000"
    from_port   = 8000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "NATS Port"
    from_port   = 4222
    to_port     = 4222
    protocol    = "tcp"
    cidr_blocks = [
      data.terraform_remote_state.core_state.outputs.ec2_private_1a_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1b_cidr,
      data.terraform_remote_state.core_state.outputs.ec2_private_1c_cidr
    ]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Extend node-to-node security group rules
  ingress {
    description      = "Node to node all ports/protocols"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    self             = true
  }

  egress {
    description      = "To node 1025-65535"
    from_port        = 1025
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Node all egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.tags, local.resources_tags)

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}
