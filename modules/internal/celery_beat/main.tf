resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_stream" "this" {
  name           = var.log_stream_prefix
  log_group_name = aws_cloudwatch_log_group.this.name
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${terraform.workspace}-${var.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  container_definitions = jsonencode([
    {
      name        = var.name
      image       = var.image
      essential   = true
      links       = []
      user        = "root" # needed to fix [Errno 13] Permission denied: 'celerybeat-schedule'
      environment = var.env_vars
      command     = var.command
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = var.log_stream_prefix
        }
      }
    }
  ])
  task_role_arn      = var.task_role_arn
  execution_role_arn = var.execution_role_arn
}

resource "aws_ecs_service" "this" {
  name            = "${terraform.workspace}_${var.name}"
  cluster         = var.ecs_cluster_id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.app_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 0
  }

  network_configuration {
    assign_public_ip = true
    security_groups  = [var.ecs_sg_id]
    subnets          = var.private_subnets
  }
}
