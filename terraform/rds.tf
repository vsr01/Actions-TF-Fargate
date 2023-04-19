# -----------------------------------------------------------------------------
# RDS MySQL + Secrets Manager (application credentials)
#
# RDS lives in *private* subnets only; the app resolves the hostname from Secrets Manager.
# The secret version includes the RDS address so Terraform wires the dependency automatically.
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "${var.project_name}-db-subnets"
  }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.project_name}-mysql"
  allocated_storage      = 20
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  db_name                = "myappdb"
  username               = "appadmin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "${var.project_name}-mysql"
  }
}

resource "aws_secretsmanager_secret" "db_creds" {
  name = "${var.project_name}/prod/db-creds"
}

resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    username = "appadmin"
    password = var.db_password
    host     = aws_db_instance.mysql.address
    db_name  = "myappdb"
  })
}
