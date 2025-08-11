# SECURITY GAP: This creates an issue that requires fixes in BOTH folders

# IAM role that assumes the main terraform IAM role
resource "aws_iam_role" "cross_folder_role" {
  name = "startup-cross-folder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # SECURITY ISSUE: References the overpermissive role from terraform/iam-policies.tf
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/gomboc-test-app-role"
        }
        # SECURITY ISSUE: No conditions - inherits admin access
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

# This security issue can only be properly fixed by changing BOTH:
# 1. terraform/iam-policies.tf (reduce permissions on source role)
# 2. This file (add proper conditions)
