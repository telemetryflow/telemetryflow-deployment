# ==========================================================================
#  Module Compute: iam-profile.tf
# --------------------------------------------------------------------------
#  Description:
#    IAM Role + Instance Profile for EC2 (SSM + S3 read-only)
# ==========================================================================

resource "aws_iam_role" "ec2_role" {
  name = "${var.prefix_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Create the instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.prefix_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  depends_on = [aws_iam_role.ec2_role]
}
