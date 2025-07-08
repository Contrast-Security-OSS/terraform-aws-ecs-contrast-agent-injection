# Basic test fixture for enabled Contrast agent

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Local variables
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Test-specific naming
  app_name = "${var.unique_id}-test-app"
  vpc_cidr = "10.1.0.0/16"

  tags = {
    Test        = "true"
    TestId      = var.unique_id
    Environment = "test"
    Application = local.app_name
  }
}

# VPC
resource "aws_vpc" "test" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${local.app_name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id

  tags = merge(local.tags, {
    Name = "${local.app_name}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.test.id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.app_name}-public-${count.index + 1}"
    Type = "Public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.test.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = merge(local.tags, {
    Name = "${local.app_name}-private-${count.index + 1}"
    Type = "Private"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = length(local.azs)

  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${local.app_name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.test]
}

# NAT Gateways
resource "aws_nat_gateway" "test" {
  count = length(local.azs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, {
    Name = "${local.app_name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.test]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }

  tags = merge(local.tags, {
    Name = "${local.app_name}-public-rt"
  })
}

resource "aws_route_table" "private" {
  count = length(local.azs)

  vpc_id = aws_vpc.test.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.test[count.index].id
  }

  tags = merge(local.tags, {
    Name = "${local.app_name}-private-rt-${count.index + 1}"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Group
resource "aws_security_group" "test" {
  name        = "${local.app_name}-sg"
  description = "Security group for ${local.app_name}"
  vpc_id      = aws_vpc.test.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.app_name}-sg"
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.app_name}"
  retention_in_days = 1

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "contrast" {
  count             = var.contrast_enabled ? 1 : 0
  name              = "/ecs/${local.app_name}/contrast-init"
  retention_in_days = 1

  tags = local.tags
}

# IAM Roles
resource "aws_iam_role" "ecs_execution" {
  name = "${local.app_name}-ecs-execution"

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

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${local.app_name}-ecs-task"

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

  tags = local.tags
}

# ECS Cluster
resource "aws_ecs_cluster" "test" {
  name = "${local.app_name}-cluster"

  tags = local.tags
}

# Contrast Sidecar Module
module "contrast_sidecar" {
  source = "../../../terraform-module"

  enabled                = var.contrast_enabled
  application_name       = local.app_name
  contrast_api_url       = var.contrast_api_url
  contrast_api_key       = var.contrast_api_key
  contrast_service_key   = var.contrast_service_key
  contrast_user_name     = var.contrast_user_name
  environment            = "DEVELOPMENT"
  contrast_log_level     = "INFO"
  log_group_name         = var.contrast_enabled ? aws_cloudwatch_log_group.contrast[0].name : ""
  log_retention_days     = 1
  contrast_agent_version = var.contrast_agent_version

  tags = local.tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "test" {
  family                   = local.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  # Add Contrast volume if enabled
  dynamic "volume" {
    for_each = module.contrast_sidecar.volume_config != null ? [1] : []
    content {
      name = module.contrast_sidecar.volume_config.name
    }
  }

  container_definitions = jsonencode(concat(
    # Application container
    [merge({
      name      = local.app_name
      image     = var.app_image
      essential = true

      # Mount Contrast volume
      mountPoints = module.contrast_sidecar.app_mount_points

      # Port mappings
      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]

      # Resource allocation
      cpu    = var.app_cpu
      memory = var.app_memory

      # Environment variables
      environment = concat(
        module.contrast_sidecar.environment_variables,
        [
          {
            name  = "APP_ENV"
            value = "test"
          },
          {
            name  = "TEST_MODE"
            value = "true"
          }
        ]
      )

      # Logging
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }, length(module.contrast_sidecar.container_dependencies) > 0 ? {
      # Add Contrast dependencies only if they exist
      dependsOn = module.contrast_sidecar.container_dependencies
    } : {})],

    # Contrast init container
    module.contrast_sidecar.init_container_definitions
  ))

  tags = local.tags
}

# ECS Service
resource "aws_ecs_service" "test" {
  name            = local.app_name
  cluster         = aws_ecs_cluster.test.id
  task_definition = aws_ecs_task_definition.test.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.test.id]
    assign_public_ip = false
  }

  tags = local.tags

  depends_on = [
    aws_nat_gateway.test
  ]
}
