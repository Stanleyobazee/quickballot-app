output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  value = aws_subnet.database[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways (empty when enable_nat_gateway is false)"
  value       = aws_nat_gateway.main[*].id
}

output "ecr_repository_urls" {
  description = "Repository URLs by service"
  value       = { for name, repo in aws_ecr_repository.service : name => repo.repository_url }
}
