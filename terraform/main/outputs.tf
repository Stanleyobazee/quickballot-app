output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, one per availability zone"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, one per availability zone"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of the database subnets, one per availability zone"
  value       = aws_subnet.database[*].id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables, one per availability zone"
  value       = aws_route_table.private[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways (empty when enable_nat_gateway is false)"
  value       = aws_nat_gateway.main[*].id
}

output "ecr_repository_urls" {
  description = "Repository URLs by service"
  value       = { for name, repo in aws_ecr_repository.service : name => repo.repository_url }
}
