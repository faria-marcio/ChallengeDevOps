output "rds_security_group_id" {
  value = aws_security_group.main.id
}

output "rds_db_password" {
  value = random_password.pw.result
}

output "rds_db_host" {
  value = aws_db_instance.rds_instance.endpoint
}

