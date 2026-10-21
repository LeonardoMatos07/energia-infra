data "aws_rds_engine_version" "postgres" {
  engine  = "postgres"
  version = var.engine_version
  latest  = true
}

resource "aws_db_subnet_group" "this" {
  name       = var.name_prefix
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-rds"
  description = "PostgreSQL: only from the API tasks and the Airflow instance"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-rds" }
}

resource "aws_vpc_security_group_ingress_rule" "clients" {
  for_each = var.allowed_security_group_ids

  security_group_id            = aws_security_group.this.id
  description                  = "PostgreSQL from ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = each.value
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name_prefix}-${data.aws_rds_engine_version.postgres.parameter_group_family}"
  family = data.aws_rds_engine_version.postgres.parameter_group_family

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.name_prefix
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name                     = var.db_name
  username                    = var.master_username
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_days
  backup_window              = "05:00-06:00"
  maintenance_window         = "sun:06:30-sun:07:30"
  copy_tags_to_snapshot      = true
  deletion_protection        = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${var.name_prefix}-final"
  auto_minor_version_upgrade = true
  apply_immediately          = false
}

resource "random_password" "app" {
  for_each = toset(["energia_api", "energia_data"])

  length  = 32
  special = false
}

locals {
  host = aws_db_instance.this.address
  port = aws_db_instance.this.port
}

resource "aws_secretsmanager_secret" "api_database" {
  name                    = "${var.secrets_prefix}/api/database"
  description             = "Credentials and DATABASE_URL of the energia_api database user"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "api_database" {
  secret_id = aws_secretsmanager_secret.api_database.id
  secret_string = jsonencode({
    username = "energia_api"
    password = random_password.app["energia_api"].result
    host     = local.host
    port     = local.port
    dbname   = var.db_name
    url      = "${var.database_url_scheme}://energia_api:${random_password.app["energia_api"].result}@${local.host}:${local.port}/${var.db_name}?sslmode=require"
  })
}

resource "aws_secretsmanager_secret" "data_warehouse" {
  name                    = "${var.secrets_prefix}/data/warehouse"
  description             = "Credentials and WAREHOUSE_DSN of the energia_data database user"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "data_warehouse" {
  secret_id = aws_secretsmanager_secret.data_warehouse.id
  secret_string = jsonencode({
    username = "energia_data"
    password = random_password.app["energia_data"].result
    host     = local.host
    port     = local.port
    dbname   = var.db_name
    dsn      = "postgresql://energia_data:${random_password.app["energia_data"].result}@${local.host}:${local.port}/${var.db_name}?sslmode=require"
  })
}
