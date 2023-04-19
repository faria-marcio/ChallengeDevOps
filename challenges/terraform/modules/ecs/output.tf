output "ecs_cluster" {
  value = aws_ecs_cluster.fargate_cluster.id
}

output "fargate_sg_id" {
  value = aws_security_group.fargate_cluster_service_security_group.id
}
