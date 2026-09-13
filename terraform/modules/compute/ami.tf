# --------------------------------------------------------------------------
#  Data Sources - AMI lookup (latest stable)
# --------------------------------------------------------------------------
# Only the data source matching var.ami_os is read during plan;
# the others are disabled via count to avoid failed lookups.

# Data source for Ubuntu 24.04 LTS (Noble Numbat)
# https://cloud-images.ubuntu.com/locator/ec2/

data "aws_ami" "ubuntu" {
  provider    = aws.destination
  count       = var.ami_os == "ubuntu" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Data source for Debian 13 (Trixie) - current stable
# https://wiki.debian.org/Cloud/AmazonEC2

data "aws_ami" "debian" {
  provider    = aws.destination
  count       = var.ami_os == "debian" ? 1 : 0
  most_recent = true
  owners      = ["136693071363"] # Debian Official

  filter {
    name   = "name"
    values = ["debian-13-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Data source for Amazon Linux 2023

data "aws_ami" "amazon_linux_2023" {
  provider    = aws.destination
  count       = var.ami_os == "amazon_linux_2023" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  ami_os_map = {
    ubuntu            = try(data.aws_ami.ubuntu[0].id, null)
    debian            = try(data.aws_ami.debian[0].id, null)
    amazon_linux_2023 = try(data.aws_ami.amazon_linux_2023[0].id, null)
  }

  selected_ami_id = local.ami_os_map[var.ami_os]
}
