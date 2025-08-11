resource "aws_s3_bucket" "public_website" {
  bucket = "${var.project_name}-public-website-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_public_access_block" "public_website" {
  bucket = aws_s3_bucket.public_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
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
