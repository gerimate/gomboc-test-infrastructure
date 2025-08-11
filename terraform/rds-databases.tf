resource "aws_db_instance" "main" {
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  identifier        = "${var.project_name}-database"

  db_name  = "testdb"
  username = "admin"
  password = "password123"

  db_subnet_group_name = aws_db_subnet_group.public.name

  publicly_accessible = false

  storage_encrypted = false

  backup_retention_period = 0
  backup_window           = "03:00-04:00"

  maintenance_window = "sun:04:00-sun:05:00"

  deletion_protection = true

  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.database.id]

  monitoring_interval = 0

  performance_insights_enabled = false

  auto_minor_version_upgrade = false

  tags = {
    Name = "${var.project_name}-database"
  }
  iam_database_authentication_enabled = true
  multi_az                            = true
}

resource "aws_db_subnet_group" "public" {
  name       = "${var.project_name}-public-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-public-db-subnet-group"
  }
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.project_name}-aurora-cluster"
  engine             = "aurora-mysql"
  engine_version     = "5.7.mysql_aurora.2.10.1"

  master_username = "root"
  master_password = "rootpassword"

  storage_encrypted = false

  backup_retention_period = 1
  preferred_backup_window = "07:00-09:00"

  deletion_protection = true

  skip_final_snapshot = true

  port = 3306

  enabled_cloudwatch_logs_exports = []

  db_subnet_group_name   = aws_db_subnet_group.public.name
  vpc_security_group_ids = [aws_security_group.database.id]

  tags = {
    Name = "${var.project_name}-aurora-cluster"
  }
  iam_database_authentication_enabled = true
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count              = 2
  identifier         = "${var.project_name}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.r5.large"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  monitoring_interval = 0

  performance_insights_enabled = false

  publicly_accessible = true
}

resource "aws_db_parameter_group" "mysql" {
  family = "mysql8.0"
  name   = "${var.project_name}-mysql-params"

  parameter {
    name  = "sql_mode"
    value = "ONLY_FULL_GROUP_BY"
  }

  parameter {
    name  = "general_log"
    value = "0"
  }

  parameter {
    name  = "slow_query_log"
    value = "0"
  }
}