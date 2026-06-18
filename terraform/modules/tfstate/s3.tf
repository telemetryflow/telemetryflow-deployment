# ==========================================================================
#  Module TFState: s3.tf
# --------------------------------------------------------------------------
#  Description
#    S3 Bucket for storing Terraform state objects
# --------------------------------------------------------------------------
#    - Private ACL
#    - Versioning enabled
#    - SSE-S3 encryption
#    - Public access block (all blocked)
#    - Lifecycle rules (non-current versions)
# ==========================================================================

locals {
  s3_tags = {
    Name          = local.bucket_name
    ResourceGroup = "${var.environment[local.env]}-S3-TFSTATE"
  }
}

# --------------------------------------------------------------------------
#  S3 Bucket
# --------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  provider = aws.destination
  bucket   = local.bucket_name

  tags = merge(local.tags, local.s3_tags)
}

# --------------------------------------------------------------------------
#  Versioning
# --------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "tfstate" {
  provider = aws.destination
  bucket   = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --------------------------------------------------------------------------
#  Server-Side Encryption (SSE-S3, AWS-managed keys)
# --------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  provider = aws.destination
  bucket   = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --------------------------------------------------------------------------
#  Public Access Block (block all public access)
# --------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "tfstate" {
  provider                = aws.destination
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------------------------------
#  Deny insecure transport (enforce TLS)
# --------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "tfstate" {
  provider = aws.destination
  bucket   = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# --------------------------------------------------------------------------
#  Lifecycle - expire old non-current versions
# --------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  provider = aws.destination
  bucket   = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
  }
}

# --------------------------------------------------------------------------
#  Ownership controls
# --------------------------------------------------------------------------
resource "aws_s3_bucket_ownership_controls" "tfstate" {
  provider = aws.destination
  bucket   = aws_s3_bucket.tfstate.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
