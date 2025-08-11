# SECURITY TEST: Cross-folder dependency that creates security issues

# Reference the main VPC from terraform/ folder
data "terraform_remote_state" "main_infra" {
  backend = "local"
  config = {
    path = "../../terraform/terraform.tfstate"
  }
}

# SECURITY ISSUE: Using the insecure security group from main terraform/
resource "aws_instance" "cross_folder_instance" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  # This creates a security dependency across folders
  vpc_security_group_ids = [
    data.terraform_remote_state.main_infra.outputs.insecure_admin_sg_id
  ]

  # SECURITY ISSUE: This instance inherits the 0.0.0.0/0 SSH access
  # from terraform/ec2-instances.tf but Gomboc might not see the connection

  tags = {
    Name    = "cross-folder-test"
    Purpose = "Testing Gomboc cross-folder analysis"
  }
  tenancy                 = "dedicated"
  disable_api_termination = true
  monitoring              = true
}

# SECURITY ISSUE: S3 bucket policy that references main VPC
resource "aws_s3_bucket_policy" "cross_folder_policy" {
  bucket = aws_s3_bucket.file_uploads.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "VPCEndpointAccess"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.file_uploads.arn}/*"
        Condition = {
          StringEquals = {
            # References main VPC CIDR - security depends on main folder
            "aws:sourceVpc" = data.terraform_remote_state.main_infra.outputs.main_vpc_id
          }
        }
      }
    ]
  })
}