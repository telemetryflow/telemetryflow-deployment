# ==========================================================================
#  Module Network: nat.tf
# --------------------------------------------------------------------------
#  Description
#    NAT Gateway for EC2 - OPTIONAL (single AZ)
# --------------------------------------------------------------------------
#    - EIP (enabled when NAT is enabled)
#    - Single NAT Gateway in Public Subnet zone-a
#    - Route Table for Private Subnet (a) -> NAT Gateway
# --------------------------------------------------------------------------
#  Note: A single NAT GW (in zone-a) serves the private subnet.
# ==========================================================================

# --------------------------------------------------------------------------
#  NAT GW Tags
# --------------------------------------------------------------------------
locals {
  tags_nat_ec2_rt_private = {
    ResourceGroup = "${var.environment[local.env]}-RT-EC2"
  }

  tags_nat_ec2 = {
    ResourceGroup = "${var.environment[local.env]}-NAT-EC2"
  }
}

# --------------------------------------------------------------------------
#  EIP (enabled)
# --------------------------------------------------------------------------
resource "aws_eip" "ec2" {
  count    = var.enable_nat ? 1 : 0
  provider = aws.destination
  domain   = "vpc"

  tags = {
    Name = "${var.coreinfra}-${var.workspace_env[local.env]}-eip-ec2"
  }

  tags_all = {
    Name = "${var.coreinfra}-${var.workspace_env[local.env]}-eip-ec2"
  }
}

# --------------------------------------------------------------------------
#  NAT GW (zone-a)
# --------------------------------------------------------------------------
resource "aws_nat_gateway" "ec2_ngw" {
  count         = var.enable_nat ? 1 : 0
  provider      = aws.destination
  allocation_id = aws_eip.ec2[0].id
  subnet_id     = aws_subnet.ec2_public_a.id

  tags = merge(local.tags, local.tags_nat_ec2, {
    Name = "${var.coreinfra}-${var.workspace_env[local.env]}-${var.nat_ec2_prefix}"
  })

  depends_on = [aws_internet_gateway.igw]

  lifecycle {
    ignore_changes = [
      allocation_id
    ]
  }
}

# --------------------------------------------------------------------------
#  Route Table NAT GW (a private subnet -> single NAT GW)
# --------------------------------------------------------------------------
resource "aws_route_table" "nat_ec2_rt_private" {
  count    = var.enable_nat ? 1 : 0
  provider = aws.destination
  vpc_id   = aws_vpc.infra_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ec2_ngw[0].id
  }

  tags = merge(local.tags, local.tags_nat_ec2_rt_private, {
    Name = "${var.coreinfra}-${var.workspace_env[local.env]}-${var.ec2_rt_prefix}-private-${var.aws_region}a"
  })
}

# --------------------------------------------------------------------------
#  Route Table Association with Private Subnet (a)
# --------------------------------------------------------------------------
resource "aws_route_table_association" "nat_ec2_rt_private_a" {
  count          = var.enable_nat ? 1 : 0
  provider       = aws.destination
  subnet_id      = aws_subnet.ec2_private_a.id
  route_table_id = aws_route_table.nat_ec2_rt_private[0].id
}
