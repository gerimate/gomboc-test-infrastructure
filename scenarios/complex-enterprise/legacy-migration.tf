# Complex Enterprise Scenario: Legacy system migration with security debt
# Represents a large enterprise migrating legacy workloads with accumulated security issues

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ==================== LEGACY VPC ARCHITECTURE ====================
# SECURITY ISSUE: Overly complex network with too many trust boundaries

resource "aws_vpc" "legacy_vpc" {
  cidr_block           = "172.16.0.0/12"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "legacy-migration-vpc"
    Project = "LegacyMigration"
    CostCenter = "IT-INFRA-001"
  }
}

resource "aws_subnet" "dmz" {
  count             = 3
  vpc_id            = aws_vpc.legacy_vpc.id
  cidr_block        = "172.16.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true

  tags = {
    Name = "legacy-dmz-${count.index + 1}"
    Tier = "DMZ"
    Purpose = "UnknownLegacyUse"
  }
}

resource "aws_subnet" "app_tier" {
  count             = 3
  vpc_id            = aws_vpc.legacy_vpc.id
  cidr_block        = "172.16.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "legacy-app-${count.index + 1}"
    Tier = "Application"
  }
}

resource "aws_subnet" "data_tier" {
  count             = 3
  vpc_id            = aws_vpc.legacy_vpc.id
  cidr_block        = "172.16.${count.index + 20}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "legacy-data-${count.index + 1}"
    Tier = "Database"
  }
}

# ==================== OVERLY PERMISSIVE LEGACY SECURITY GROUPS ====================

resource "aws_security_group" "legacy_admin" {
  name        = "legacy-admin-access"
  description = "Legacy admin access - inherited from on-prem"
  vpc_id      = aws_vpc.legacy_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/12", "10.0.0.0/8"]
    description = "SSH from internal networks"
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/12"]
    description = "RDP from VPC"
  }

  ingress {
    from_port   = 23
    to_port     = 23
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/24"]
    description = "Telnet from DMZ - LEGACY ONLY"
  }

  ingress {
    from_port   = 161
    to_port     = 161
    protocol    = "udp"
    cidr_blocks = ["172.16.0.0/12"]
    description = "SNMP monitoring"
  }

  ingress {
    from_port   = 8080
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/12"]
    description = "Legacy application ports"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "legacy-admin-sg"
    Purpose = "AdminAccess"
    Legacy = "true"
  }
}

resource "aws_security_group" "legacy_database" {
  name        = "legacy-database-access"
  description = "Legacy database access patterns"
  vpc_id      = aws_vpc.legacy_vpc.id

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["172.16.10.0/24", "172.16.11.0/24", "172.16.12.0/24"]
    description = "SQL Server from app tier"
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["172.16.10.0/24", "172.16.11.0/24", "172.16.12.0/24"]
    description = "MySQL from app tier"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["172.16.10.0/24", "172.16.11.0/24", "172.16.12.0/24"]
    description = "PostgreSQL from app tier"
  }

  ingress {
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/12"]
    description = "Oracle from entire VPC"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.legacy_admin.id]
    description = "SSH from admin security group"
  }

  tags = {
    Name = "legacy-database-sg"
    Purpose = "DatabaseAccess"
  }
}

# ==================== LEGACY IAM WITH EXCESSIVE PERMISSIONS ====================

resource "aws_iam_user" "legacy_service_account" {
  name = "legacy-migration-service"
  path = "/legacy/"

  tags = {
    Purpose = "LegacyMigration"
    Department = "IT"
  }
}

resource "aws_iam_access_key" "legacy_service" {
  user = aws_iam_user.legacy_service_account.name
}

resource "aws_iam_policy" "legacy_migration_policy" {
  name        = "LegacyMigrationPolicy"
  description = "Policy for legacy system migration - TEMPORARY"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "rds:*",
          "s3:*",
          "iam:ListRoles",
          "iam:PassRole",
          "lambda:*",
          "logs:*",
          "cloudformation:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "legacy_service_attachment" {
  user       = aws_iam_user.legacy_service_account.name
  policy_arn = aws_iam_policy.legacy_migration_policy.arn
}

resource "aws_iam_role" "legacy_cross_account" {
  name = "legacy-cross-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::111122223333:root",
            "arn:aws:iam::444455556666:root"
          ]
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "legacy123"
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "LegacyCrossAccount"
  }
}

# ==================== LEGACY DATABASE INSTANCES ====================

resource "aws_db_instance" "legacy_oracle" {
  allocated_storage      = 100
  storage_type          = "gp2"
  engine                = "oracle-ee"
  engine_version        = "19.0.0.0.ru-2019-07.rur-2019-07.r1"
  instance_class        = "db.t3.medium"
  identifier            = "legacy-oracle-prod"
  
  username = "SYSTEM"
  password = "LegacyOracle2019!"
  
  storage_encrypted         = false
  publicly_accessible      = false
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  deletion_protection       = false
  skip_final_snapshot       = true
  
  db_subnet_group_name      = aws_db_subnet_group.legacy_data.name
  vpc_security_group_ids    = [aws_security_group.legacy_database.id]
  
  monitoring_interval = 0
  
  license_model = "bring-your-own-license"

  tags = {
    Name = "legacy-oracle-prod"
    Environment = "production"
    LegacySystem = "ERP"
    Criticality = "high"
  }
}

resource "aws_db_subnet_group" "legacy_data" {
  name       = "legacy-data-subnet-group"
  subnet_ids = aws_subnet.data_tier[*].id

  tags = {
    Name = "legacy-data-subnet-group"
  }
}

resource "aws_db_instance" "legacy_sqlserver" {
  allocated_storage     = 200
  storage_type         = "gp2"
  engine               = "sqlserver-ex"
  engine_version       = "14.00.3356.20.v1"
  instance_class       = "db.t3.medium"
  identifier           = "legacy-sqlserver-crm"
  
  username = "sa"
  password = "SqlServer2019!"
  
  storage_encrypted       = false
  publicly_accessible    = false
  backup_retention_period = 3
  deletion_protection     = false
  skip_final_snapshot     = true
  
  db_subnet_group_name   = aws_db_subnet_group.legacy_data.name
  vpc_security_group_ids = [aws_security_group.legacy_database.id]
  
  tags = {
    Name = "legacy-sqlserver-crm"
    Environment = "production"
    LegacySystem = "CRM"
  }
}

# ==================== LEGACY EC2 INSTANCES ====================

resource "aws_instance" "legacy_app_server" {
  count         = 3
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "m5.large"
  subnet_id     = aws_subnet.app_tier[count.index].id
  
  vpc_security_group_ids = [
    aws_security_group.legacy_admin.id,
    aws_security_group.legacy_app.id
  ]
  
  key_name = aws_key_pair.legacy_admin.key_name
  
  root_block_device {
    volume_type = "gp3"
    volume_size = 50
    encrypted   = false
  }
  
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = 100
    encrypted   = false
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  iam_instance_profile = aws_iam_instance_profile.legacy_app.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd mysql
    systemctl start httpd
    systemctl enable httpd
    
    echo "DB_HOST=${aws_db_instance.legacy_oracle.endpoint}" >> /etc/environment
    echo "DB_USER=SYSTEM" >> /etc/environment
    echo "DB_PASS=LegacyOracle2019!" >> /etc/environment
    
    wget https://legacy-monitoring-bucket.s3.amazonaws.com/agent.sh
    chmod +x agent.sh
    ./agent.sh install --admin-mode
  EOF

  tags = {
    Name = "legacy-app-server-${count.index + 1}"
    Environment = "production"
    LegacyApp = "ERP-Frontend"
    MaintenanceWindow = "Sunday-3AM"
  }
}

resource "aws_security_group" "legacy_app" {
  name        = "legacy-application-sg"
  description = "Legacy application security group"
  vpc_id      = aws_vpc.legacy_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
    description = "HTTP from DMZ"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
    description = "HTTPS from DMZ"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/12"]
    description = "Legacy app port"
  }

  ingress {
    from_port   = 9443
    to_port     = 9443
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/12"]
    description = "Legacy admin console"
  }

  ingress {
    from_port   = 9999
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/12"]
    description = "JMX monitoring"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "legacy-application-sg"
  }
}

resource "aws_key_pair" "legacy_admin" {
  key_name   = "legacy-admin-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7YourLegacyKeyHere..."

  tags = {
    Name = "legacy-admin-key"
    CreatedDate = "2019-01-01"
    LastRotation = "never"
  }
}

resource "aws_iam_role" "legacy_app_role" {
  name = "legacy-app-role"

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

  tags = {
    Purpose = "LegacyAppAccess"
  }
}

resource "aws_iam_policy" "legacy_app_policy" {
  name        = "legacy-app-policy"
  description = "Legacy application policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::legacy-*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:SendCommand"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "legacy_app_attachment" {
  role       = aws_iam_role.legacy_app_role.name
  policy_arn = aws_iam_policy.legacy_app_policy.arn
}

resource "aws_iam_instance_profile" "legacy_app" {
  name = "legacy-app-profile"
  role = aws_iam_role.legacy_app_role.name
}

# ==================== LEGACY STORAGE ====================

resource "aws_s3_bucket" "legacy_file_share" {
  bucket = "legacy-file-share-${random_id.legacy_suffix.hex}"

  tags = {
    Name = "legacy-file-share"
    Purpose = "LegacyFileSharing"
    Compliance = "none"
  }
}

resource "aws_s3_bucket_policy" "legacy_file_share" {
  bucket = aws_s3_bucket.legacy_file_share.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "LegacyPublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.legacy_file_share.arn}/*"
        Condition = {
          StringEquals = {
            "s3:ExistingObjectTag/Legacy" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "legacy_backups" {
  bucket = "legacy-system-backups-${random_id.legacy_suffix.hex}"

  tags = {
    Name = "legacy-backups"
    Purpose = "SystemBackups"
    RetentionYears = "7"
  }
}

resource "random_id" "legacy_suffix" {
  byte_length = 6
}

# ==================== NETWORKING ====================

resource "aws_internet_gateway" "legacy_igw" {
  vpc_id = aws_vpc.legacy_vpc.id

  tags = {
    Name = "legacy-igw"
  }
}

resource "aws_route_table" "legacy_public" {
  vpc_id = aws_vpc.legacy_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.legacy_igw.id
  }

  route {
    cidr_block = "10.0.0.0/8"
    gateway_id = aws_vpn_gateway.legacy_vpn.id
  }

  tags = {
    Name = "legacy-public-rt"
  }
}

resource "aws_vpn_gateway" "legacy_vpn" {
  vpc_id = aws_vpc.legacy_vpc.id

  tags = {
    Name = "legacy-vpn-gw"
    Purpose = "OnPremConnectivity"
  }
}

resource "aws_route_table_association" "dmz" {
  count          = 3
  subnet_id      = aws_subnet.dmz[count.index].id
  route_table_id = aws_route_table.legacy_public.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ==================== OUTPUTS ====================

output "legacy_infrastructure_summary" {
  value = {
    vpc_id = aws_vpc.legacy_vpc.id
    vpc_cidr = aws_vpc.legacy_vpc.cidr_block
    database_endpoints = {
      oracle = aws_db_instance.legacy_oracle.endpoint
      sqlserver = aws_db_instance.legacy_sqlserver.endpoint
    }
    app_servers = aws_instance.legacy_app_server[*].private_ip
    security_groups = {
      admin = aws_security_group.legacy_admin.id
      database = aws_security_group.legacy_database.id
      application = aws_security_group.legacy_app.id
    }
    storage = {
      file_share = aws_s3_bucket.legacy_file_share.bucket
      backups = aws_s3_bucket.legacy_backups.bucket
    }
  }
  description = "Legacy infrastructure components requiring security review"
}

output "security_recommendations" {
  value = [
    "Rotate legacy admin key pair",
    "Enable encryption on all RDS instances",
    "Implement least privilege IAM policies",
    "Remove public access from file share bucket",
    "Enable VPC Flow Logs",
    "Implement proper network segmentation",
    "Update database engine versions",
    "Enable CloudTrail logging",
    "Implement backup encryption",
    "Review and restrict security group rules"
  ]
  description = "Critical security improvements needed"
}
