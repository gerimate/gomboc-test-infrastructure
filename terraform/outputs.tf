# Outputs for cross-folder testing
output "main_vpc_id" {
  value       = aws_vpc.main.id
  description = "Main VPC ID for use by other modules"
}

output "main_vpc_cidr" {
  value       = aws_vpc.main.cidr_block
  description = "Main VPC CIDR block"
}

output "insecure_admin_sg_id" {
  value       = aws_security_group.web_servers.id
  description = "SECURITY ISSUE: Exposing insecure SG for cross-folder use"
}
