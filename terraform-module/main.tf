# Main Terraform module for ECS Contrast Agent Sidecar

locals {
  # Define the shared volume name
  volume_name = "contrast-agent-storage"
  
  # Path where the agent will be mounted in the application container
  app_mount_path = "/opt/contrast/java"
  
  # Path where the init container will write the agent
  init_mount_path = "/mnt/contrast"
  
  # Generate a unique server name if not provided
  contrast_server_name = var.server_name != "" ? var.server_name : "${var.application_name}-${data.aws_region.current.name}"
  
  # Build the init container definition
  init_container = var.enabled ? [{
    name      = "contrast-init"
    image     = var.init_container_image
    essential = false
    
    # Command to copy the agent JAR to the shared volume
    command = [
      "sh", "-c",
      "cp /contrast/contrast-agent.jar ${local.init_mount_path}/contrast.jar && echo 'Contrast agent copied successfully'"
    ]
    
    # Mount the shared volume
    mountPoints = [{
      sourceVolume  = local.volume_name
      containerPath = local.init_mount_path
    }]
    
    # Logging configuration
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name != "" ? var.log_group_name : "/ecs/contrast-init"
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "contrast-init"
      }
    }
    
    # Resource limits for the init container
    cpu    = var.init_container_cpu
    memory = var.init_container_memory
  }] : []
  
  # Environment variables for the Contrast agent
  contrast_env_vars = var.enabled ? [
    {
      name  = "CONTRAST_ENABLED"
      value = "true"
    },
    {
      name  = "CONTRAST__API__URL"
      value = var.contrast_api_url
    },
    {
      name  = "CONTRAST__API__API_KEY"
      value = var.contrast_api_key
    },
    {
      name  = "CONTRAST__API__SERVICE_KEY"
      value = var.contrast_service_key
    },
    {
      name  = "CONTRAST__API__USER_NAME"
      value = var.contrast_user_name
    },
    {
      name  = "CONTRAST__APPLICATION__NAME"
      value = var.application_name
    },
    {
      name  = "CONTRAST__SERVER__NAME"
      value = local.contrast_server_name
    },
    {
      name  = "CONTRAST__SERVER__ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "CONTRAST__AGENT__LOGGER__LEVEL"
      value = var.contrast_log_level
    }
  ] : [
    {
      name  = "CONTRAST_ENABLED"
      value = "false"
    }
  ]
  
  # Additional optional environment variables
  optional_env_vars = var.enabled ? [
    for key, value in var.additional_env_vars : {
      name  = key
      value = value
    }
  ] : []
  
  # Application container mount points
  app_mount_points = var.enabled ? [{
    sourceVolume  = local.volume_name
    containerPath = local.app_mount_path
    readOnly      = true
  }] : []
  
  # Dependencies for the application container
  container_dependencies = var.enabled ? [{
    containerName = "contrast-init"
    condition     = "SUCCESS"
  }] : []
  
  # Volume configuration
  volume_config = var.enabled ? {
    name = local.volume_name
  } : null
}

# Data source for current AWS region
data "aws_region" "current" {}
