resource "aws_iam_role" "ecs_role" {
  name = "${var.name}-ecsRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-role-execution-policy-attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs-role-logs-policy-attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster"
  tags = {
    Name        = "${var.name}-cluster"
  }
}

resource "aws_ecs_task_definition" "main" {
  count                    = length(var.name_suffix)
  family                   = "${var.name}-task-${var.name_suffix[count.index]}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_role.arn
  task_role_arn            = aws_iam_role.ecs_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
    # cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name        = "${var.name}-container-${var.name_suffix[count.index]}"
      image       = "${var.ecr_repository_urls[count.index]}:latest"
      essential   = true
      portMappings = [
        {
          protocol      = "tcp"
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/fargate/${var.name}-${var.name_suffix[count.index]}"
          awslogs-region        = "${var.region}"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.name}-task-${var.name_suffix[count.index]}"
  }
}

resource "aws_ecs_service" "main" {
  count                              = length(var.name_suffix)
  name                               = "${var.name}-service-${var.name_suffix[count.index]}"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.main[count.index].arn
  desired_count                      = var.service_desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  scheduling_strategy                = "REPLICA"

  capacity_provider_strategy {
    base = 0
    capacity_provider = "FARGATE_SPOT"
    weight = 100
  }

  network_configuration {
    security_groups  = var.ecs_service_security_groups
    subnets          = var.subnets.*.id
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_cloudwatch_log_group" "main" {
  count             = length(var.name_suffix)
  name              = "/ecs/fargate/${var.name}-${var.name_suffix[count.index]}"
  retention_in_days = 1
}
