resource "aws_db_subnet_group" "main" {
  count      = var.enable_database ? 1 : 0
  name       = "${var.project}-database"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "${var.project}-database"
  }
}

# No ingress rules yet. The node security group is added here with EKS.
resource "aws_security_group" "database" {
  count       = var.enable_database ? 1 : 0
  name        = "${var.project}-database"
  description = "PostgreSQL access for ${var.project}"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-database"
  }
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
