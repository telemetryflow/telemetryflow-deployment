# ==========================================================================
#  Module Compute: rke2-sg.tf
# --------------------------------------------------------------------------
#  Description
#    Security Group for RKE2 Kubernetes cluster traffic
# --------------------------------------------------------------------------
#  All control-plane and intra-cluster ports are scoped to the VPC CIDR
#  so the API server / etcd / kubelet are NOT exposed to the internet.
#  Public ingress (80/443 for NGINX Ingress, 22 for SSH) lives in the
#  `main` security group.
#
#  Reference: https://docs.rke2.io/install/requirements#networking
# ==========================================================================

locals {
  sg_rke2 = {
    Name          = "${var.prefix_name}-rke2-sg"
    ResourceGroup = "${var.environment[local.env]}-SG-RKE2"
  }

  # CIDRs allowed to reach the Kubernetes API server.
  # VPC CIDR is always included (control-plane + kubelet traffic).
  # Add external CIDRs (e.g. your office IP) via var.rke2_api_access_cidrs.
  rke2_api_cidrs = distinct(concat([var.vpc_cidr], var.rke2_api_access_cidrs))
}

# --------------------------------------------------------------------------
#  RKE2 Security Group
# --------------------------------------------------------------------------
resource "aws_security_group" "rke2" {
  count       = var.create_rke2_sg ? 1 : 0
  name        = "${var.prefix_name}-rke2-sg"
  description = "RKE2 Kubernetes cluster internal + API ports"
  vpc_id      = var.vpc_id

  # ── Kubernetes API server (6443) ────────────────────────────────
  # VPC + optionally external CIDRs for kubectl from workstation.
  ingress {
    description = "Kubernetes API server (6443)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = local.rke2_api_cidrs
  }

  # ── RKE2 supervisor / agent registration (9345) ─────────────────
  ingress {
    description = "RKE2 supervisor — agent registration (9345)"
    from_port   = 9345
    to_port     = 9345
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ── etcd server client + peer (2379-2380) ───────────────────────
  # Server-to-server. Harmless on single-master; required for HA.
  ingress {
    description = "etcd server client + peer (2379-2380)"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ── kubelet API (10250) ─────────────────────────────────────────
  ingress {
    description = "kubelet API (10250)"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ── kubelet read-only + kube-proxy metrics (10256) ──────────────
  ingress {
    description = "kube-proxy health/metrics (10256)"
    from_port   = 10256
    to_port     = 10256
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ── CIS benchmark / node scanner (4240) ─────────────────────────
  ingress {
    description = "CIS benchmark scanner (4240)"
    from_port   = 4240
    to_port     = 4240
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ── Calico BGP (179) ────────────────────────────────────────────
  ingress {
    description = "Calico BGP (179)"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ── Calico Typha (5473) ─────────────────────────────────────────
  ingress {
    description = "Calico Typha (5473)"
    from_port   = 5473
    to_port     = 5473
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ── CNI VXLAN overlay (Calico + Flannel) ────────────────────────
  ingress {
    description = "CNI VXLAN overlay — Calico (4789/udp)"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "CNI VXLAN overlay — Flannel (8472/udp)"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ── Kubernetes NodePort range (30000-32767) ─────────────────────
  # Used by Rancher/Kite/NodePort services. Scoped to VPC by default.
  ingress {
    description = "Kubernetes NodePort range (30000-32767) — VPC"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ── All egress ──────────────────────────────────────────────────
  egress {
    description = "RKE2 node all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, local.sg_rke2)
}

# --------------------------------------------------------------------------
#  Local: ordered list of security group IDs applied to every instance
#  (main + instance-connect + optional RKE2)
# --------------------------------------------------------------------------
locals {
  ec2_security_group_ids = concat(
    [
      aws_security_group.main.id,
      aws_security_group.instance_connect.id,
    ],
    var.create_rke2_sg ? [aws_security_group.rke2[0].id] : []
  )
}
