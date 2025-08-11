# Startup Basic Scenario: Simple 3-tier web app with common security oversights
# This represents what a small startup might deploy without proper security review

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "startup_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "startup-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.startup_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "startup-public-subnet"
  }
}

resource "aws_internet_gateway" "startup_igw" {
  vpc_id = aws_vpc.startup_vpc.id

  tags = {
    Name = "startup-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.startup_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.startup_igw.id
  }

  tags = {
    Name = "startup-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "database" {
  name_prefix = "startup-db-"
  vpc_id      = aws_vpc.startup_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "startup-db-sg"
  }
}

resource "aws_db_instance" "startup_db" {
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  identifier        = "startup-database"

  db_name  = "startupapp"
  username = "admin"
  password = "StartupPass123!"

  publicly_accessible     = false
  storage_encrypted       = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = true

  db_subnet_group_name   = aws_db_subnet_group.startup.name
  vpc_security_group_ids = [aws_security_group.database.id]

  tags = {
    Name        = "startup-database"
    Environment = "production"
  }
  iam_database_authentication_enabled = true
  multi_az                            = true
}

resource "aws_db_subnet_group" "startup" {
  name       = "startup-db-subnet-group"
  subnet_ids = [aws_subnet.public.id]

  tags = {
    Name = "startup-db-subnet-group"
  }
}

resource "aws_security_group" "web" {
  name_prefix = "startup-web-"
  vpc_id      = aws_vpc.startup_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "startup-web-sg"
  }
}

resource "aws_instance" "web_server" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = false
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Startup Website</h1>" > /var/www/html/index.html
    echo "<p>Database connection string: mysql://admin:StartupPass123!@${aws_db_instance.startup_db.endpoint}/startupapp</p>" >> /var/www/html/index.html
  EOF

  tags = {
    Name        = "startup-web-server"
    Environment = "production"
  }
  tenancy                 = "dedicated"
  disable_api_termination = true
  monitoring              = true
}

resource "aws_s3_bucket" "file_uploads" {
  bucket = "startup-file-uploads-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "startup-file-uploads"
    Environment = "production"
  }
}

resource "aws_s3_bucket_policy" "file_uploads" {
  bucket = aws_s3_bucket.file_uploads.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadWrite"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.file_uploads.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "file_uploads" {
  bucket = aws_s3_bucket.file_uploads.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

output "website_url" {
  value = "http://${aws_instance.web_server.public_ip}"
}

output "database_endpoint" {
  value     = aws_db_instance.startup_db.endpoint
  sensitive = false
}

output "file_upload_bucket" {
  value = aws_s3_bucket.file_uploads.bucket
}
# Testing scenario scanning
resource "aws_s3_bucket_versioning" "my_aws_s3_bucket_versioning_aws_s3_bucket_file_uploads" {
  bucket = aws_s3_bucket.file_uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}