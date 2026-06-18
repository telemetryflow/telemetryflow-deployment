# ==========================================================================
#  Module Network: igw.tf
# --------------------------------------------------------------------------
#  Description
#    Internet Gateway for EC2 (multi AZ)
# --------------------------------------------------------------------------
#    - IGW Public Subnet
#    - Route Table Public Subnet from IGW (a, b, c)
# ==========================================================================

# --------------------------------------------------------------------------
#  IGW Tags
# --------------------------------------------------------------------------
locals {
  tags_igw = {
    ResourceGroup = "${var.environment[local.env]}-IGW"
    Name          = "${var.coreinfra}-${var.workspace_env[local.env]}-${var.igw_prefix}"
  }

  tags_ec2_rt_public = {
    ResourceGroup = "${var.environment[local.env]}-RT-EC2"
    Name          = "${var.coreinfra}-${var.workspace_env[local.env]}-${var.ec2_rt_prefix}-public"
  }

  # Common route configuration for public subnets
  public_route = {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# --------------------------------------------------------------------------
#  IGW
# --------------------------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  provider = aws.destination
  vpc_id   = aws_vpc.infra_vpc.id

  tags = merge(local.tags, local.tags_igw, {
    Name = "${var.coreinfra}-${var.workspace_env[local.env]}-${var.igw_prefix}"
  })
}

# --------------------------------------------------------------------------
#  Route Table for IGW - Single Route Table pattern, one per AZ (a, b, c)
# --------------------------------------------------------------------------
resource "aws_route_table" "igw_ec2_rt_public" {
  provider = aws.destination
  for_each = toset(["a", "b", "c"])
  vpc_id   = aws_vpc.infra_vpc.id

  route {
    cidr_block = local.public_route.cidr_block
    gateway_id = local.public_route.gateway_id
  }

  tags = merge(local.tags, local.tags_ec2_rt_public, {
    Name = "${var.coreinfra}-${var.workspace_env[local.env]}-${var.ec2_rt_prefix}-public-${var.aws_region}${each.key}"
    Type = "EC2-Public"
  })
}

# --------------------------------------------------------------------------
#  Route Table Association with Public Subnets (a, b, c)
# --------------------------------------------------------------------------
resource "aws_route_table_association" "igw_ec2_rt_public" {
  provider = aws.destination
  for_each = {
    a = aws_subnet.ec2_public_a.id
    b = aws_subnet.ec2_public_b.id
    c = aws_subnet.ec2_public_c.id
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.igw_ec2_rt_public[each.key].id
}
