# Multi-Cloud Scenario: AWS + Azure with inconsistent security policies
# This shows how security configurations can drift between cloud providers

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "azurerm" {
  features {}
}

resource "aws_vpc" "aws_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "multicloud-aws-vpc"
    CloudProvider = "AWS"
    SecurityLevel = "High"
  }
}

resource "aws_subnet" "aws_public" {
  vpc_id                  = aws_vpc.aws_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "multicloud-aws-public"
  }
}

resource "aws_security_group" "aws_web" {
  name        = "multicloud-aws-web"
  description = "AWS web security group"
  vpc_id      = aws_vpc.aws_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]
    description = "SSH from company network"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "multicloud-aws-web-sg"
  }
}

resource "aws_s3_bucket" "aws_data" {
  bucket = "multicloud-aws-data-${random_id.aws_suffix.hex}"

  tags = {
    Name = "multicloud-aws-data"
    CloudProvider = "AWS"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aws_data" {
  bucket = aws_s3_bucket.aws_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "aws_data" {
  bucket = aws_s3_bucket.aws_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "aws_suffix" {
  byte_length = 4
}

# ==================== AZURE RESOURCES ====================
# Azure resources with DIFFERENT security standards - this is the problem!

resource "azurerm_resource_group" "main" {
  name     = "multicloud-rg"
  location = "East US"

  tags = {
    CloudProvider = "Azure"
    SecurityLevel = "Medium"
  }
}

resource "azurerm_virtual_network" "azure_vnet" {
  name                = "multicloud-azure-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    CloudProvider = "Azure"
  }
}

resource "azurerm_subnet" "azure_public" {
  name                 = "multicloud-azure-public"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.azure_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_security_group" "azure_web" {
  name                = "multicloud-azure-web-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    CloudProvider = "Azure"
  }
}

resource "azurerm_storage_account" "azure_data" {
  name                     = "multiclouddata${random_id.azure_suffix.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # SECURITY ISSUE: No encryption configured (AWS has it)
  # encryption {
  #   services {
  #     blob {
  #       enabled = true
  #     }
  #   }
  # }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    CloudProvider = "Azure"
  }
}

resource "azurerm_storage_container" "azure_data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.azure_data.name
  container_access_type = "blob"
}

resource "random_id" "azure_suffix" {
  byte_length = 4
}

output "aws_vpc_cidr" {
  value = aws_vpc.aws_vpc.cidr_block
  description = "AWS VPC CIDR block"
}

output "azure_vnet_cidr" {
  value = azurerm_virtual_network.azure_vnet.address_space
  description = "Azure VNet address space"
}

output "aws_ssh_access" {
  value = "Restricted to 203.0.113.0/24"
  description = "AWS SSH access policy"
}

output "azure_ssh_access" {
  value = "Open to 0.0.0.0/0"
  description = "Azure SSH access policy - INCONSISTENT!"
}

output "aws_storage_encryption" {
  value = "Enabled with AES256"
  description = "AWS S3 encryption status"
}

output "azure_storage_encryption" {
  value = "DISABLED - Security gap!"
  description = "Azure Storage encryption status"
}
