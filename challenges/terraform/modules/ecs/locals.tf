locals {
  fargate      = "FARGATE"
  fargate_spot = "FARGATE_SPOT"
  roles = [
    {
      name   = "${var.project_name}-task-execution-role-${terraform.workspace}",
      policy = templatefile("${path.module}/ecs_tasks_policy.json", {})
    },
    {
      name   = "${var.project_name}-task-role-${terraform.workspace}"
      policy = templatefile("${path.module}/ecs_tasks_policy.json", {})
    }
  ]
  policies = [
    {
      name   = "CloudWatchReadWritePolicy"
      policy = templatefile("${path.module}/cloud_watch_policy.json", {})
    }
  ]
  listeners = [
    {
      port            = 80
      protocol        = "HTTP"
      ssl_policy      = ""
      certificate_arn = ""
    }
  ]
}
