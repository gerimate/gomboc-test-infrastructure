resource "aws_s3_bucket" "public_website" {
  bucket = "${var.project_name}-public-website-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_public_access_block" "public_website" {
  bucket = aws_s3_bucket.public_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_website" {
  bucket = aws_s3_bucket.public_website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.public_website.arn}/*"
      },
      {
        Sid       = "PublicWriteObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.public_website.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket" "data_storage" {
  bucket = "${var.project_name}-data-storage-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket" "backup_storage" {
  bucket = "${var.project_name}-backups-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket" "app_logs" {
  bucket = "${var.project_name}-app-logs-${random_string.bucket_suffix.result}"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
resource "aws_s3_bucket_public_access_block" "my_aws_s3_bucket_public_access_block_aws_s3_bucket_data_storage" {
  bucket             = aws_s3_bucket.data_storage.id
  ignore_public_acls = true
}
resource "aws_s3_bucket_public_access_block" "my_aws_s3_bucket_public_access_block_aws_s3_bucket_backup_storage" {
  bucket             = aws_s3_bucket.backup_storage.id
  ignore_public_acls = true
}
resource "aws_s3_bucket_public_access_block" "my_aws_s3_bucket_public_access_block_aws_s3_bucket_app_logs" {
  bucket             = aws_s3_bucket.app_logs.id
  ignore_public_acls = true
}
resource "aws_s3_bucket_versioning" "my_aws_s3_bucket_versioning_aws_s3_bucket_public_website" {
  bucket = aws_s3_bucket.public_website.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_versioning" "my_aws_s3_bucket_versioning_aws_s3_bucket_data_storage" {
  bucket = aws_s3_bucket.data_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_versioning" "my_aws_s3_bucket_versioning_aws_s3_bucket_backup_storage" {
  bucket = aws_s3_bucket.backup_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_versioning" "my_aws_s3_bucket_versioning_aws_s3_bucket_app_logs" {
  bucket = aws_s3_bucket.app_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}