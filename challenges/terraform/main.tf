locals {
  region = "ap-southeast-2"
}

module "vpc" {
  source              = "./modules/vpc"
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  subnet_private_name = var.subnet_private_name
  subnet_private_cidr = var.subnet_private_cidr
  subnet_public_name  = var.subnet_public_name
  subnet_public_cidr  = var.subnet_public_cidr
  azs                 = var.azs
  cidr_block_all      = var.cidr_block_all
  rule_no_acl         = var.rule_no_acl
}

# module "ec2" {
#   source              = "./modules/ec2"
#   project_name        = var.project_name
#   vpc_id              = module.vpc.vpc_id
#   vpc_cidr            = var.vpc_cidr
#   subnet_private_id   = module.vpc.subnet_private_id
#   subnet_private_cidr = var.subnet_private_cidr
#   subnet_public_id    = module.vpc.subnet_public_id
#   subnet_public_cidr  = var.subnet_public_cidr
#   cidr_block_all      = var.cidr_block_all
#   ami                 = var.ami
#   instance_type       = var.instance_type
# }

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

module "rds" {
  source               = "./modules/rds"
  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = var.vpc_cidr
  subnet_private_id    = module.vpc.subnet_private_id
  app_sg_id            = module.ecs.fargate_sg_id
  db_name              = var.db_name
  db_master_username   = var.db_master_username
  db_subnet_group_name = var.db_subnet_group_name
  db_engine            = var.db_engine
  db_engine_version    = var.db_engine_version
  db_instance_class    = var.db_instance_class
}

module "ecs" {
  source                    = "./modules/ecs"
  project_name              = var.project_name
  vpc_id                    = module.vpc.vpc_id
  subnet_private_id         = module.vpc.subnet_private_id
  subnet_public_id          = module.vpc.subnet_public_id
  cw_logs_retention_in_days = 30
  rds_security_group_id     = module.rds.rds_security_group_id
  ssl_policy                = "ELBSecurityPolicy-2016-08"
  # certificate_arn           = "arn:aws:acm:${local.region}:${local.account_id}:certificate/592f3bcb-aad6-47ab-8bd2-8a386427bf6a"
  # route53_zone_id           = "Z2CM8OFXPVFSYQ"
  # route53_record_names      = [ local.api, local.auth ]
  task_execution_policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  task_policies_arn = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
  ]
  cpu                     = "1024"
  memory                  = "2048"
  desired_count           = 1
  capacity_provider       = "FARGATE"
  operating_system_family = "LINUX"
  cpu_architecture        = "X86_64"
  db_name                 = var.db_name
  db_master_username      = var.db_master_username
  db_password             = module.rds.rds_db_password
  db_host                 = module.rds.rds_db_host
  containers = [
    {
      name               = "laravel"
      image              = module.ecr.ecr_url
      memory_reservation = 128
      container_port     = 80
    }
  ]
}

