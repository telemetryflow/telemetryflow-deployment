# ==========================================================================
#  Module Compute: sg.tf
# --------------------------------------------------------------------------
#  Description
#    Security Groups
# --------------------------------------------------------------------------
#    - Instance Connect Endpoint SG
#    - EC2 Main SG (SSH / HTTP / HTTPS)
# ==========================================================================

locals {
  sg_instance_connect = {
    Name          = "${var.prefix_name}-instance-connect-sg"
    ResourceGroup = "${var.environment[local.env]}-SG-IC"
  }

  sg_main = {
    Name          = "${var.prefix_name}-ec2-sg"
    ResourceGroup = "${var.environment[local.env]}-SG-EC2"
  }
}

# --------------------------------------------------------------------------
#  Instance Connect Endpoint Security Group
# --------------------------------------------------------------------------
resource "aws_security_group" "instance_connect" {
  name        = "${var.prefix_name}-instance-connect-sg"
  description = "Security group for EC2 Instance Connect endpoint"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, local.sg_instance_connect)
}

# --------------------------------------------------------------------------
#  EC2 Main Security Group
# --------------------------------------------------------------------------
resource "aws_security_group" "main" {
  name        = "${var.prefix_name}-ec2-sg"
  description = "Security group for EC2 Instance"
  vpc_id      = var.vpc_id

  # SSH Access
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # HTTP Access
  ingress {
    description      = "HTTP Port"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # HTTPS Access
  ingress {
    description      = "HTTPS Port"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # ICMP (Ping) - Internal Only
  ingress {
    description = "ICMP - Internal VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.common_tags, local.sg_main)
}
