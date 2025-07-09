# Example Terraform configuration for a Java application with Contrast agent injection

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Local variables
locals {
  azs        = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  subnet_ids = aws_subnet.private[*].id
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.app_name}-vpc"
    Application = var.app_name
    Environment = var.environment
    Team        = var.team
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.app_name}-igw"
    Application = var.app_name
    Environment = var.environment
    Team        = var.team
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.app_name}-public-${local.azs[count.index]}"
    Type        = "Public"
    Application = var.app_name
    Environment = var.environment
    Team        = var.team
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(local.azs))
  availability_zone = local.azs[count.index]

  tags = {
    Name        = "${var.app_name}-private-${local.azs[count.index]}"
    Type        = "Private"
    Application = var.app_name
    Environment = var.environment
    Team        = var.team
  }
}

# NAT Gateway EIP
resource "aws_eip" "nat" {
  count = length(local.azs)

  domain = "vpc"

  tags = {
    Name        = "${var.app_name}-nat-${local.azs[count.index]}"
    Application = var.app_name
    Environment = var.environment
    Team        = var.team
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  count = length(local.azs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.app_name}-nat-${local.azs[count.index]}"
    Application = var.app_name
    Environment = var.environment
    Team        = var.team
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.app_name}-public-rt"
    Application = var.app_name
    Environment = var.environment
    Team        = var.team
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  count = length(local.azs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.app_name}-private-rt-${local.azs[count.index]}"
    Application = var.app_name
    Environment = var.environment
    Team        = var.team
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
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
  vpc_id      = aws_vpc.main.id

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

# Contrast Agent Injection Module
module "contrast_agent_injection" {
  source = "../../terraform-module"

  enabled                = var.contrast_enabled
  application_name       = var.app_name
  contrast_api_url       = var.contrast_api_url
  contrast_api_key       = var.contrast_api_key
  contrast_service_key   = var.contrast_service_key
  contrast_user_name     = var.contrast_user_name
  environment            = var.environment
  contrast_log_level     = var.contrast_log_level
  log_group_name         = aws_cloudwatch_log_group.contrast.name
  contrast_agent_version = var.contrast_agent_version
  enable_stdout_logging  = true

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
    for_each = module.contrast_agent_injection.volume_config != null ? [1] : []
    content {
      name = module.contrast_agent_injection.volume_config.name
    }
  }

  container_definitions = jsonencode(concat(
    # Application container
    [{
      name      = var.app_name
      image     = var.app_image
      essential = true

      # Add Contrast dependencies
      dependsOn = module.contrast_agent_injection.container_dependencies

      # Mount the Contrast volume
      mountPoints = module.contrast_agent_injection.app_mount_points

      # Ports
      portMappings = [{
        containerPort = var.app_port
        protocol      = "tcp"
      }]

      # Environment variables
      environment = concat(
        module.contrast_agent_injection.environment_variables,
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
          },
          {
            name  = "JAVA_TOOL_OPTIONS"
            value = var.contrast_enabled ? "-javaagent:${module.contrast_agent_injection.agent_path}" : ""
          }
        ]
      )

      # Health check
      # healthCheck = {
      #   command     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/WebGoat || exit 1"]
      #   interval    = 30
      #   timeout     = 5
      #   retries     = 3
      #   startPeriod = 60
      # }

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
      cpu               = var.app_cpu
      memoryReservation = var.app_memory
    }],

    # Contrast init container
    module.contrast_agent_injection.init_container_definitions
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
    subnets          = local.subnet_ids
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
  value = module.contrast_agent_injection.agent_enabled
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}

output "subnet_ids_used" {
  description = "The subnet IDs that are being used for the ECS service"
  value       = local.subnet_ids
}

output "vpc_id" {
  description = "The VPC ID being used"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the created VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "The public subnet IDs created"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "The private subnet IDs created"
  value       = aws_subnet.private[*].id
}

output "availability_zones_used" {
  description = "The availability zones used for the deployment"
  value       = local.azs
}
