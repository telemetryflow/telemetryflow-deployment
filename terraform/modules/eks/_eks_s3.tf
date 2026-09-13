# ==========================================================================
#  Module EKS: _eks_s3.tf (S3 Bucket for EKS logs / assets)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Resources Tags
#    - S3 Configuration (private, versioned, TLS-only)
# ==========================================================================

# --------------------------------------------------------------------------
#  Resources Tags
# --------------------------------------------------------------------------
locals {
  s3_tags = {
    "Name"          = "${var.eks_cluster_name}-${var.eks_name_env[local.env]}-eks-bucket"
    "ResourceGroup" = "${var.environment[local.env]}-S3-EKS"
  }
}

###############
# S3 (Object) #
###############
locals {
  bucket_name = "${var.bucket_name}-${var.eks_name_env[local.env]}"
  region      = var.aws_region
}

data "aws_canonical_user_id" "current" {}

data "aws_cloudfront_log_delivery_canonical_user_id" "cloudfront" {}

# --------------------------------------------------------------------------
#  Existing CMK (referenced by alias)
# --------------------------------------------------------------------------
data "aws_kms_key" "cmk_key" {
  key_id = var.kms_key[local.env]
}

resource "random_pet" "this" {
  length = 2
}

module "s3_bucket" {
  source = "github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v3.15.2"

  bucket        = local.bucket_name
  acl           = "private"
  force_destroy = false

  attach_policy                         = true
  policy                                = data.aws_iam_policy_document.eks_bucket_policy.json
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  tags = merge(local.tags, local.s3_tags)

  versioning = {
    enabled = true
  }

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # S3 Bucket Ownership Controls
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
}

# --------------------------------------------------------------------------
#  Bucket policy (allows the EC2/EKS node role to list the bucket)
# --------------------------------------------------------------------------
data "aws_iam_policy_document" "eks_bucket_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.eks_nodes.arn]
    }

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${local.bucket_name}",
    ]
  }
}
