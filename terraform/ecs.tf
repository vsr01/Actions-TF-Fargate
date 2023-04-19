# -----------------------------------------------------------------------------
# Amazon ECS on Fargate
#
# Mental model:
#   Cluster  -> logical home for services
#   Task definition -> blueprint (CPU/mem, container image, env/secrets, logs)
#   Service  -> keeps *desired_count* tasks running, wires ALB -> tasks
#
# Execution role: used by Fargate to pull images, write logs, read Secrets Manager.
# (A separate *task role* would be for the app calling AWS APIs; this demo does not need it.)
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  # Extra CloudWatch metrics for the cluster/services (good for learning; small cost).
  # Remove this block if you want to minimize spend during idle weeks.
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-app"
  retention_in_days = 7
}

resource "aws_iam_role" "ecs_exec" {
  name_prefix = "ecs-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_managed" {
  role       = aws_iam_role.ecs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_exec_secrets" {
  name = "${var.project_name}-ecs-exec-secrets"
  role = aws_iam_role.ecs_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.db_creds.arn
    }]
  })
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([{
    name      = "flask-app"
    essential = true
    image     = "${var.docker_username}/my-flask-app:${var.image_tag}"
    secrets = [
      { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:username::" },
      { name = "DB_PASS", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:password::" },
      { name = "DB_HOST", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:host::" },
      { name = "DB_NAME", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:db_name::" }
    ]
    portMappings = [{ containerPort = 5000, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  depends_on = [
    aws_iam_role_policy_attachment.ecs_exec_managed,
    aws_iam_role_policy.ecs_exec_secrets,
  ]
}

resource "aws_ecs_service" "main" {
  name             = "${var.project_name}-service"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.app.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  # Gives new tasks time to pass the target group's health checks before ECS/ALB give up.
  health_check_grace_period_seconds = 120

  # If new tasks never become healthy, ECS stops the bad rollout (and can roll back).
  # Watch "Deployments" in the ECS service console when you intentionally break an image.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "flask-app"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.http]
}
