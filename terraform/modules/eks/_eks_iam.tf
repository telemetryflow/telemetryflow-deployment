# ==========================================================================
#  Module EKS: _eks_iam.tf (IAM Roles & Policies)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - IAM Role for EKS Cluster
#    - IAM Role for EKS Nodes
#    - EBS CSI Driver Pod Identity Role & Policy
#    - EFS CSI Driver Pod Identity Role & Policy
#    - AWS Load Balancer Controller Policy
#    - Cluster Autoscaler Role (OIDC)
# ==========================================================================

# --------------------------------------------------------------------------
#  Data Sources
# --------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##############################################################
# IAM Role Configuration for EKS Cluster and Nodes
##############################################################
resource "aws_iam_role" "eks_cluster" {
  provider = aws.destination
  name     = "eks-role-${var.eks_cluster_name}-${var.eks_name_env[local.env]}-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_iam_cluster_policy" {
  provider   = aws.destination
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_iam_service_policy" {
  provider   = aws.destination
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role" "eks_nodes" {
  provider = aws.destination
  name     = "eks-role-${var.eks_cluster_name}-${var.eks_name_env[local.env]}-nodes"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_iam_worker_node_policy" {
  provider   = aws.destination
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_iam_cni_policy" {
  provider   = aws.destination
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_iam_container_registry_policy" {
  provider   = aws.destination
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

##############################################################
# Route53 cert policy (for cert-manager DNS validation)
##############################################################
resource "aws_iam_policy" "route53_cert_policy" {
  provider = aws.destination
  name     = "aws-route53-cert-${var.eks_cluster_name}-${var.eks_name_env[local.env]}"
  policy   = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [{
      "Action": "route53:GetChange",
      "Effect": "Allow",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:route53:::hostedzone/${var.dns_zone[local.env]}"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "route53_cert_policy" {
  provider   = aws.destination
  policy_arn = aws_iam_policy.route53_cert_policy.arn
  role       = aws_iam_role.eks_nodes.name
}

##############################################################
### EBS CSI Driver with Pod Identity ###
##############################################################
resource "aws_iam_role" "ebs_csi_pod_identity_role" {
  provider = aws.destination
  name     = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Name            = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}-ebs-csi-driver-role"
      Type            = "EKS-Pod-Identity"
      ProductName     = "EKS-EBS-CSI"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Services        = "EBS-CSI"
    }
  )
}

resource "aws_iam_policy" "ebs_csi_driver_policy" {
  provider    = aws.destination
  name        = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}-ebs-csi-driver-policy"
  description = "IAM policy for EBS CSI driver with Pod Identity"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateVolume",
              "CreateSnapshot"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/CSIVolumeName" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/CSIVolumeName" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/kubernetes.io/created-for/pvc/name" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/CSIVolumeSnapshotName" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      }
    ]
  })

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Name            = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}-ebs-csi-driver-policy"
      Type            = "IAM-Policy"
      ProductName     = "EKS-EBS-CSI"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Services        = "EBS-CSI"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy_attachment" {
  provider   = aws.destination
  role       = aws_iam_role.ebs_csi_pod_identity_role.name
  policy_arn = aws_iam_policy.ebs_csi_driver_policy.arn
}

##############################################################
### EFS CSI Driver with Pod Identity ###
##############################################################
resource "aws_iam_role" "efs_csi_pod_identity_role" {
  provider = aws.destination
  name     = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}-efs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Name            = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}-efs-csi-driver-role"
      Type            = "EKS-Pod-Identity"
      ProductName     = "EKS-EFS-CSI"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Services        = "EFS-CSI"
    }
  )
}

resource "aws_iam_policy" "efs_csi_driver_policy" {
  provider    = aws.destination
  name        = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}-efs-csi-driver-policy"
  description = "IAM policy for EFS CSI driver with Pod Identity"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateAccessPoint"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "elasticfilesystem:DeleteAccessPoint"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      }
    ]
  })

  tags = merge(
    local.tags,
    local.resources_tags,
    {
      Name            = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}-efs-csi-driver-policy"
      Type            = "IAM-Policy"
      ProductName     = "EKS-EFS-CSI"
      ProductGroup    = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Department      = var.department
      DepartmentGroup = var.eks_name_env[local.env] == "prod" ? "PROD-${var.department}" : "STG-${var.department}"
      ResourceGroup   = var.eks_name_env[local.env] == "prod" ? "PROD-EKS-CSI" : "STG-EKS-CSI"
      Services        = "EFS-CSI"
    }
  )
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver_policy_attachment" {
  provider   = aws.destination
  role       = aws_iam_role.efs_csi_pod_identity_role.name
  policy_arn = aws_iam_policy.efs_csi_driver_policy.arn
}

##############################################################
### EKS Cluster Autoscaler (CA) - OIDC Web Identity ###
##############################################################
locals {
  cluster_oidc_path = format("oidc.eks.%s.amazonaws.com/id/%s", var.aws_region, join("", regex("https://([^.]+).+", aws_eks_cluster.aws_eks.endpoint)))
}

resource "aws_iam_role" "cluster_autoscaler_role" {
  provider = aws.destination
  name     = "cluster-autoscaler-${var.eks_cluster_name}-${var.eks_name_env[local.env]}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.cluster_oidc_path}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.cluster_oidc_path}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cluster_autoscaler_policy" {
  provider = aws.destination
  name     = "cluster-autoscaler-${var.eks_cluster_name}-${var.eks_name_env[local.env]}-policy"
  role     = aws_iam_role.cluster_autoscaler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy" "node_autoscaler_policy" {
  provider = aws.destination
  name     = "node-autoscaler-${var.eks_cluster_name}-${var.eks_name_env[local.env]}-policy"
  role     = aws_iam_role.eks_nodes.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
        Effect   = "Allow"
      }
    ]
  })
}

##############################################################
### AWS Load Balancer Controller (attached to node role) ###
##############################################################
resource "aws_iam_policy" "load_balancer_controller_policy" {
  provider = aws.destination
  name     = "aws-loadbalancer-controller-${var.eks_cluster_name}-${var.eks_name_env[local.env]}"
  policy   = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:GetSubscriptionState",
                "shield:DescribeProtection",
                "shield:CreateProtection",
                "shield:DeleteProtection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "StringEquals": {
                    "elasticloadbalancing:CreateAction": [
                        "CreateTargetGroup",
                        "CreateLoadBalancer"
                    ]
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller_policy" {
  provider   = aws.destination
  policy_arn = aws_iam_policy.load_balancer_controller_policy.arn
  role       = aws_iam_role.eks_nodes.name
}
