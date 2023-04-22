# RDS

## Security Group
resource "aws_security_group" "main" {
  name        = "${var.project_name}-rds"
  description = "Allow inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = [var.vpc_cidr]
    security_groups = [var.app_sg_id]
  }
  tags = {
    Name = "${var.project_name}-rds"
  }
}

## Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = var.db_subnet_group_name
  subnet_ids = var.subnet_private_id
}

## Password
resource "random_password" "pw" {
  length  = 8
  upper   = true
  special = false
}

## SSM Parameters
resource "aws_ssm_parameter" "db_host" {
  name        = "/rds/DB_HOST"
  description = "The host parameter to be used by the container"
  type        = "SecureString"
  value       = aws_db_instance.rds_instance.endpoint
}
resource "aws_ssm_parameter" "db_user" {
  name        = "/rds/DB_USER"
  description = "The user parameter to be used by the container"
  type        = "SecureString"
  value       = var.db_master_username
}
resource "aws_ssm_parameter" "db_password" {
  name        = "/rds/DB_PASSWORD"
  description = "The password parameter to be used by the container"
  type        = "SecureString"
  value       = random_password.pw.result
}
resource "aws_ssm_parameter" "db_name" {
  name        = "/rds/DB_NAME"
  description = "The name parameter to be used by the container"
  type        = "SecureString"
  value       = var.db_name
}

## Instance
resource "aws_db_instance" "rds_instance" {
  identifier                  = var.db_name
  engine                      = var.db_engine
  engine_version              = var.db_engine_version
  instance_class              = var.db_instance_class
  allocated_storage           = 5
  db_name                     = var.db_name
  username                    = var.db_master_username
  password                    = random_password.pw.result
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.main.id]
  allow_major_version_upgrade = true
  skip_final_snapshot         = true

  tags = {
    Name = "${var.project_name}-rds"
  }
}

