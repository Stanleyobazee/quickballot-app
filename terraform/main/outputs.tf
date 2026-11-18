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

output "database_endpoint" {
  description = "Connection endpoint of the database (null when enable_database is false)"
  value       = one(aws_db_instance.main[*].endpoint)
}

output "database_security_group_id" {
  description = "ID of the database security group (null when enable_database is false)"
  value       = one(aws_security_group.database[*].id)
}

output "database_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master password (null when enable_database is false)"
  value       = one(aws_db_instance.main[*].master_user_secret[0].secret_arn)
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster (null when enable_eks is false)"
  value       = one(aws_eks_cluster.main[*].name)
}

output "eks_cluster_endpoint" {
  description = "API server endpoint of the EKS cluster (null when enable_eks is false)"
  value       = one(aws_eks_cluster.main[*].endpoint)
}

output "eks_cluster_security_group_id" {
  description = "ID of the cluster primary security group (null when enable_eks is false)"
  value       = one(aws_eks_cluster.main[*].vpc_config[0].cluster_security_group_id)
}

output "eks_update_kubeconfig_command" {
  description = "Command that adds the cluster to the local kubeconfig (null when enable_eks is false)"
  value       = var.enable_eks ? "aws eks update-kubeconfig --name ${aws_eks_cluster.main[0].name} --region ${var.region}" : null
}
