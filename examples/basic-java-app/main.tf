# Example Terraform configuration for a Java application with Contrast sidecar

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  
  tags = {
    Type = "private"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "contrast" {
  name              = "/ecs/${var.app_name}/contrast-init"
  retention_in_days = 7
}

# IAM Roles
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.app_name}-ecs-task-execution"
  
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.app_name}-ecs-task"
  
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

# Security Group
resource "aws_security_group" "app" {
  name        = "${var.app_name}-sg"
  description = "Security group for ${var.app_name}"
  vpc_id      = data.aws_vpc.main.id
  
  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Contrast Sidecar Module
module "contrast_sidecar" {
  source = "../../terraform-module"
  
  enabled              = var.contrast_enabled
  application_name     = var.app_name
  contrast_api_url     = var.contrast_api_url
  contrast_api_key     = var.contrast_api_key
  contrast_service_key = var.contrast_service_key
  contrast_user_name   = var.contrast_user_name
  environment          = var.environment
  contrast_log_level   = "INFO"
  log_group_name       = aws_cloudwatch_log_group.contrast.name
  
  # Add custom tags
  tags = {
    Team        = var.team
    Application = var.app_name
    Environment = var.environment
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  
  # Add the Contrast volume if enabled
  dynamic "volume" {
    for_each = module.contrast_sidecar.volume_config != null ? [1] : []
    content {
      name = module.contrast_sidecar.volume_config.name
    }
  }
  
  container_definitions = jsonencode(concat(
    # Application container
    [{
      name      = var.app_name
      image     = var.app_image
      essential = true
      
      # Add Contrast dependencies
      dependsOn = module.contrast_sidecar.container_dependencies
      
      # Mount the Contrast volume
      mountPoints = module.contrast_sidecar.app_mount_points
      
      # Ports
      portMappings = [{
        containerPort = var.app_port
        protocol      = "tcp"
      }]
      
      # Environment variables
      environment = concat(
        module.contrast_sidecar.environment_variables,
        [
          {
            name  = "APP_NAME"
            value = var.app_name
          },
          {
            name  = "APP_ENV"
            value = var.environment
          },
          {
            name  = "APP_PORT"
            value = tostring(var.app_port)
          }
        ]
      )
      
      # Health check
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      
      # Logging
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
      
      # Resource limits
      cpu    = var.app_cpu
      memory = var.app_memory
    }],
    
    # Contrast init container
    module.contrast_sidecar.init_container_definitions
  ))
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = var.app_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }
  
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  
  # Optional: Add load balancer configuration here
}

# Outputs
output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "contrast_enabled" {
  value = module.contrast_sidecar.agent_enabled
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}
