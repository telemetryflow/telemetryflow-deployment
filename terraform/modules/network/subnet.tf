# ==========================================================================
#  Module Network: subnet.tf
# --------------------------------------------------------------------------
#  Description
#    Subnet Main - Single AZ (zone-a)
# --------------------------------------------------------------------------
#    - Subnet Tags
#    - Private Subnet EC2 (a)
#    - Public Subnet EC2 (a)
# ==========================================================================

# --------------------------------------------------------------------------
#  Subnet Tags
# --------------------------------------------------------------------------
locals {
  tags_ec2_public_subnet = {
    ResourceGroup = "${var.environment[local.env]}-PUB-EC2"
  }

  tags_ec2_private_subnet = {
    ResourceGroup = "${var.environment[local.env]}-PRIV-EC2"
  }

  tags_elb = {
    "kubernetes.io/role/elb" = "1"
  }

  tags_internal_elb = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# --------------------------------------------------------------------------
#  Private Subnet (a)
# --------------------------------------------------------------------------
resource "aws_subnet" "ec2_private_a" {
  provider          = aws.destination
  vpc_id            = aws_vpc.infra_vpc.id
  cidr_block        = var.ec2_private_a[local.env]
  availability_zone = "${var.aws_region}a"

  tags = merge(local.tags, local.tags_ec2_private_subnet, {
    Name = "${var.coreinfra}-${var.workspace_env[local.env]}-private-${var.ec2_prefix}-${var.aws_region}a"
  }, local.tags_internal_elb)
}

# --------------------------------------------------------------------------
#  Public Subnet (a)
# --------------------------------------------------------------------------
resource "aws_subnet" "ec2_public_a" {
  provider                = aws.destination
  vpc_id                  = aws_vpc.infra_vpc.id
  cidr_block              = var.ec2_public_a[local.env]
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.tags, local.tags_ec2_public_subnet, {
    Name = "${var.coreinfra}-${var.workspace_env[local.env]}-public-${var.ec2_prefix}-${var.aws_region}a"
  }, local.tags_internal_elb)
}
