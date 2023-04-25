# SHARED
project_name   = "dnx-devops-challenge-dev"
cidr_block_all = "0.0.0.0/0"

# VPC
vpc_cidr            = "10.100.0.0/16"
azs                 = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
subnet_private_name = ["private-a", "private-b", "private-c"]
subnet_private_cidr = ["10.100.48.0/20", "10.100.64.0/20", "10.100.80.0/20"]
subnet_public_name  = ["public-a", "public-b", "public-c"]
subnet_public_cidr  = ["10.100.0.0/20", "10.100.16.0/20", "10.100.32.0/20"]
rule_no_acl         = 100

# EC2
ami           = "ami-08f0bc76ca5236b20"
instance_type = "t2.micro"

# RDS
db_name              = "homesteaddb"
db_engine            = "mysql"
db_engine_version    = "8.0.32"
db_instance_class    = "db.t3.micro"
db_master_username   = "homestead"
db_subnet_group_name = "homestead"
