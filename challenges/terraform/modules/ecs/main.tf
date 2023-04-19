# ECS FARGATE CLUSTER
resource "aws_ecs_cluster" "fargate_cluster" {
  name = var.project_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECS FARGATE CAPACITY PROVIDERS
resource "aws_ecs_cluster_capacity_providers" "fargate_cluster_capacity_provider" {
  cluster_name       = aws_ecs_cluster.fargate_cluster.name
  capacity_providers = [local.fargate, local.fargate_spot]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = var.capacity_provider
  }
}

# CLOUDWATCH - CREATES A LOG GROUP FOR EACH CONTAINER
resource "aws_cloudwatch_log_group" "main" {
  count             = length(var.containers.*.name)
  name              = "/ecs/${aws_ecs_cluster.fargate_cluster.name}/containers/${var.containers[count.index].name}"
  retention_in_days = var.cw_logs_retention_in_days
}

# IAM
## Creates a role for each item in local.roles
resource "aws_iam_role" "main" {
  count              = length(local.roles)
  name               = local.roles[count.index].name
  assume_role_policy = local.roles[count.index].policy
}

## Attach task execution policy to task-execution-role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_attachment" {
  role       = local.roles[0].name
  policy_arn = var.task_execution_policy_arn
  depends_on = [aws_iam_role.main]
}

## Creates a policy for each item in local.policies
resource "aws_iam_policy" "main" {
  count  = length(local.policies)
  name   = local.policies[count.index].name
  policy = local.policies[count.index].policy
}

## Attach all new policies in local.policies to task-role
resource "aws_iam_role_policy_attachment" "new_policies" {
  role       = local.roles[1].name
  count      = length(local.policies)
  policy_arn = aws_iam_policy.main[count.index].arn
  depends_on = [aws_iam_role.main]
}

## Attach all existing policies in task_policies_arn to task-role
resource "aws_iam_role_policy_attachment" "existing_policies" {
  role       = local.roles[1].name
  count      = length(var.task_policies_arn)
  policy_arn = var.task_policies_arn[count.index]
  depends_on = [aws_iam_role.main]
}

# ECS TASK DEFITION
## Task Definition
resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${var.project_name}-td"
  execution_role_arn       = aws_iam_role.main[0].arn
  task_role_arn            = aws_iam_role.main[1].arn
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  requires_compatibilities = [local.fargate]
  container_definitions = templatefile(
    "${path.module}/container_definitions.tftpl",
    {
      containers    = var.containers
      cw_log_groups = aws_cloudwatch_log_group.main[*].name,
      cw_log_stream = "${var.project_name}"
    }
  )
  runtime_platform {
    operating_system_family = var.operating_system_family
    cpu_architecture        = var.cpu_architecture
  }
}

# SECURITY GROUP
## Application Load Balancer Security Group 
resource "aws_security_group" "fargate_cluster_application_load_balancer_security_group" {
  name        = "${var.project_name}-svc-alb-sg"
  description = "Manage access to ${var.project_name}-svc-alb"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

## ECS Security Group 
resource "aws_security_group" "fargate_cluster_service_security_group" {
  name        = "${var.project_name}-svc-sg"
  description = "Manage access to ${var.project_name}-svc"
  vpc_id      = var.vpc_id
  ingress {
    description     = "Connections from the ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_cluster_application_load_balancer_security_group.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-svc-sg"
  }
}

# LOAD BALANCER
## Application Load Balancer
resource "aws_alb" "fargate_cluster_application_load_balancer" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.fargate_cluster_application_load_balancer_security_group.id]
  subnets            = var.default_subnets
}

## Target Group
resource "aws_alb_target_group" "fargate_cluster_target_group" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

## Creates a alb listener for each item in local.listeners
resource "aws_alb_listener" "main" {
  load_balancer_arn = aws_alb.fargate_cluster_application_load_balancer.arn
  count             = length(local.listeners)
  port              = local.listeners[count.index].port
  protocol          = local.listeners[count.index].protocol
  ssl_policy        = local.listeners[count.index].ssl_policy
  # certificate_arn   = local.listeners[count.index].certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.fargate_cluster_target_group.arn
  }
}

# ROUTE 53 - Creates a route53 record for each item in var.route53_record_names
# resource "aws_route53_record" "main" {
#   zone_id = var.route53_zone_id
#   count   = length(var.route53_record_names)
#   name    = var.route53_record_names[count.index]
#   type    = "A"
#   alias {
#     name                   = aws_alb.fargate_cluster_application_load_balancer.dns_name
#     zone_id                = aws_alb.fargate_cluster_application_load_balancer.zone_id
#     evaluate_target_health = true
#   }
# }

# ECS FARGATE CLUSTER SERVICE
resource "aws_ecs_service" "fargate_cluster_service" {
  name            = "${var.project_name}-svc"
  cluster         = aws_ecs_cluster.fargate_cluster.id
  task_definition = aws_ecs_task_definition.task_definition.arn
  desired_count   = var.desired_count
  launch_type     = local.fargate
  network_configuration {
    subnets          = var.default_subnets
    security_groups  = [aws_security_group.fargate_cluster_service_security_group.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.fargate_cluster_target_group.arn
    container_name   = var.containers[0].name
    container_port   = var.containers[0].container_port
  }
  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "fargate_cluster_service_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.fargate_cluster.name}/${aws_ecs_service.fargate_cluster_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "fargate_cluster_service_policy" {
  name               = "${var.project_name}-svc-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.fargate_cluster_service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.fargate_cluster_service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.fargate_cluster_service_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 70
  }
}
