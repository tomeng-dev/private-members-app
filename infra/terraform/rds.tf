resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}"
  subnet_ids = aws_subnet.private[*].id
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_db_instance" "main" {
  identifier                 = "${var.project_name}-${var.environment}"
  engine                     = "mysql"
  engine_version             = "8.0"
  instance_class             = var.db_instance_class
  allocated_storage          = 50
  max_allocated_storage      = 200
  storage_encrypted          = true
  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [aws_security_group.rds.id]
  username                   = "pmadmin"
  password                   = random_password.db.result
  db_name                    = "private_members"
  multi_az                   = var.db_multi_az
  backup_retention_period    = var.environment == "production" ? 14 : 3
  deletion_protection        = var.environment == "production"
  skip_final_snapshot        = var.environment != "production"
  publicly_accessible        = false
  auto_minor_version_upgrade = true
}
