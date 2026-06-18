# ==========================================================================
#  Module Compute: instance.tf
# --------------------------------------------------------------------------
#  Description
#    Launch Template + EC2 Instances (zone-a)
# --------------------------------------------------------------------------
#    - Launch Template (shared — instance_type set per-pool)
#    - EC2 Instances via for_each over flattened var.node_pools
# ==========================================================================

# --------------------------------------------------------------------------
#  Flatten node_pools into a map of instances keyed by "{pool}-{NN}"
# --------------------------------------------------------------------------
locals {
  node_instances = merge([
    for pool_name, pool in var.node_pools : {
      for i in range(1, pool.count + 1) :
      "${pool_name}-${format("%02d", i)}" => {
        pool_name              = pool_name
        index                  = i
        instance_type          = pool.instance_type
        role                   = pool.role
        name                   = "${var.prefix_name}-${pool_name}-${format("%02d", i)}"
        root_volume_size       = pool.root_volume_size
        root_volume_type       = pool.root_volume_type
        root_volume_iops       = pool.root_volume_iops
        root_volume_throughput = pool.root_volume_throughput
      }
    }
  ]...)
}

# --------------------------------------------------------------------------
#  Launch Template
# --------------------------------------------------------------------------
resource "aws_launch_template" "main" {
  name                   = "${var.prefix_name}-template"
  image_id               = local.selected_ami_id
  key_name               = var.key_pair_name
  update_default_version = true

  # Network Configuration with Security Groups
  # (main + instance-connect + optional RKE2 — see rke2-sg.tf local)
  network_interfaces {
    associate_public_ip_address = var.enable_access_public_ip
    security_groups             = local.ec2_security_group_ids
    delete_on_termination       = true
  }

  # IAM Instance Profile
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # NOTE: Block device mappings are set per-instance (root_block_device on
  # aws_instance) so each pool can have its own size/type/iops/throughput.

  # User Data
  user_data = base64encode(
    templatefile(
      "${path.module}/template/user_data.sh",
      {
        ENVIRONMENT = "${local.env}"
        environment = "${local.env}"
        REGION      = "${local.aws_region}"
        region      = "${local.aws_region}"
        HOSTNAME    = "${local.prefix_name}-${local.env}"
        hostname    = "${local.prefix_name}-${local.env}"
      }
    )
  )

  # Monitoring
  monitoring {
    enabled = true
  }

  # Spot Instances Support
  dynamic "instance_market_options" {
    for_each = var.use_spot_instances ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price = var.spot_price
      }
    }
  }

  # Metadata Options (IMDSv2 enforced)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Instance Tags
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = "${var.prefix_name}-instance"
      }
    )
  }

  # Volume Tags
  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.common_tags,
      {
        Name = "${var.prefix_name}-volume"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------------------------------------
#  EC2 Instances (all in zone-a, one per node_pools entry)
# --------------------------------------------------------------------------
resource "aws_instance" "main" {
  for_each = local.node_instances

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  # Instance type comes from the node pool, not the launch template
  instance_type = each.value.instance_type

  # All instances placed in zone-a (single AZ)
  subnet_id = var.enable_access_public_ip ? var.public_subnet_id : var.private_subnet_id

  vpc_security_group_ids = local.ec2_security_group_ids

  associate_public_ip_address = var.enable_access_public_ip

  tags = merge(
    local.common_tags,
    {
      Name     = each.value.name
      Role     = each.value.role
      NodePool = each.value.pool_name
    }
  )

  # Enable detailed monitoring
  monitoring = true

  # Root volume — size/type/iops/throughput from the node pool
  root_block_device {
    volume_size           = each.value.root_volume_size
    volume_type           = each.value.root_volume_type
    iops                  = each.value.root_volume_type == "gp3" ? each.value.root_volume_iops : null
    throughput            = each.value.root_volume_type == "gp3" ? each.value.root_volume_throughput : null
    encrypted             = true
    delete_on_termination = true

    tags = merge(
      local.common_tags,
      {
        Name = "${each.value.name}-volume"
      }
    )
  }

  lifecycle {
    prevent_destroy = false # Set to true in production
  }
}

# --------------------------------------------------------------------------
#  Instance Connect Endpoint (optional)
# --------------------------------------------------------------------------
resource "aws_ec2_instance_connect_endpoint" "main" {
  count     = var.create_instance_connect ? 1 : 0
  subnet_id = var.private_subnet_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.prefix_name}-connect"
    }
  )
}
