resource "aws_db_subnet_group" "main" {
  count      = var.enable_database ? 1 : 0
  name       = "${var.project}-database"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "${var.project}-database"
  }
}

# Ingress comes from the EKS cluster security group, added below when both
# enable_database and enable_eks are true. Without EKS there are no ingress rules.
resource "aws_security_group" "database" {
  count       = var.enable_database ? 1 : 0
  name        = "${var.project}-database"
  description = "PostgreSQL access for ${var.project}"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-database"
  }
}

resource "aws_vpc_security_group_ingress_rule" "database_from_eks" {
  count                        = var.enable_database && var.enable_eks ? 1 : 0
  security_group_id            = aws_security_group.database[0].id
  referenced_security_group_id = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from the EKS cluster security group"
}

resource "aws_db_instance" "main" {
  count      = var.enable_database ? 1 : 0
  identifier = "${var.project}-postgres"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = "dbadmin"

  # RDS generates the master password and stores it in Secrets Manager.
  manage_master_user_password = true

  storage_type           = "gp3"
  allocated_storage      = var.db_allocated_storage
  storage_encrypted      = true
  multi_az               = false
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.database[0].id]

  backup_retention_period    = 1
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  deletion_protection        = false
  skip_final_snapshot        = true

  tags = {
    Name = "${var.project}-postgres"
  }
}
