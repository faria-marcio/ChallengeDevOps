variable "project_name" {}
variable "vpc_id" {}
variable "subnet_private_id" {}
variable "subnet_public_id" {}
variable "cw_logs_retention_in_days" {}
variable "rds_security_group_id" {}
variable "ssl_policy" {}
# variable "certificate_arn" {}
# variable route53_zone_id {}
# variable route53_record_names {}
variable "task_execution_policy_arn" {}
variable "task_policies_arn" {}

variable "cpu" {}
variable "memory" {}
variable "desired_count" {}
variable "capacity_provider" {}
variable "operating_system_family" {}
variable "cpu_architecture" {}
variable "db_name" {}
variable "db_master_username" {}
variable "db_password" {}
variable "db_host" {}
variable "containers" {
  type = list(object({
    name               = string
    image              = string
    memory_reservation = number
    container_port     = number
  }))
}
