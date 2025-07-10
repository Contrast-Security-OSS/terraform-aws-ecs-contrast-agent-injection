# Main Terraform module for ECS Contrast Agent Injection - Multi-Agent Support

locals {
  # Agent-specific configuration
  agent_configs = {
    java = {
      image_name       = "contrast/agent-java"
      mount_path       = "/opt/contrast/java"
      agent_filename   = "contrast-agent.jar"
      activation_env   = "JAVA_TOOL_OPTIONS"
      activation_value = "-javaagent:/opt/contrast/java/contrast-agent.jar"
      specific_env_vars = [
        {
          name  = "CONTRAST__AGENT__JAVA__STANDALONE_APP_NAME"
          value = var.application_name
        },
        {
          name  = "CONTRAST__AGENT__JAVA__SCAN_ALL_CLASSES"
          value = "false"
        },
        {
          name  = "CONTRAST__AGENT__JAVA__SCAN_ALL_CODE_SOURCES"
          value = "false"
        }
      ]
    }
  }

  # Get current agent configuration
  current_agent_config = local.agent_configs[var.agent_type]

  # Define the shared volume name
  volume_name = "contrast-agent-storage"

  # Path where the agent will be mounted in the application container
  app_mount_path = local.current_agent_config.mount_path

  # Path where the init container will write the agent
  init_mount_path = "/mnt/contrast"

  # Generate a unique server name if not provided
  contrast_server_name = var.server_name != "" ? var.server_name : "${var.application_name}-${data.aws_region.current.id}"

  # Build the init container definition with agent-specific image
  init_container = var.enabled ? [{
    name      = "contrast-init"
    image     = var.contrast_agent_version != "latest" ? "${local.current_agent_config.image_name}:${var.contrast_agent_version}" : "${local.current_agent_config.image_name}:latest"
    essential = false

    # Run as root to have permissions to write to mounted volume
    user = "0"

    # Set environment variable for the container's entrypoint script
    environment = [{
      name  = "CONTRAST_MOUNT_PATH"
      value = local.init_mount_path
      }, {
      name  = "CONTRAST_AGENT_TYPE"
      value = var.agent_type
    }]

    # Mount the shared volume
    mountPoints = [{
      sourceVolume  = local.volume_name
      containerPath = local.init_mount_path
    }]

    # Logging configuration
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = data.aws_region.current.id
        "awslogs-stream-prefix" = "contrast-init"
      }
    }

    # Resource limits for the init container
    cpu               = var.init_container_cpu
    memoryReservation = var.init_container_memory
  }] : []

  # Base environment variables for the Contrast agent (common to all agent types)
  base_contrast_env_vars = var.enabled ? [
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
    },
    {
      name  = "CONTRAST__AGENT__LOGGER__STDOUT"
      value = var.enable_stdout_logging ? "true" : "false"
    },
    {
      name  = "CONTRAST__AGENT__SECURITY_LOGGER__LEVEL"
      value = var.contrast_log_level
    },
    {
      name  = "CONTRAST__AGENT__SECURITY_LOGGER__STDOUT"
      value = var.enable_stdout_logging ? "true" : "false"
    },
    {
      name  = "CONTRAST__ASSESS__CACHE__HIERARCHY_ENABLE"
      value = "false"
    },
    # Add the activation environment variable
    {
      name  = local.current_agent_config.activation_env
      value = local.current_agent_config.activation_value
    }
    ] : [
    {
      name  = "CONTRAST_ENABLED"
      value = "false"
    }
  ]

  # Combine base environment variables with agent-specific ones
  contrast_env_vars = var.enabled ? concat(
    local.base_contrast_env_vars,
    local.current_agent_config.specific_env_vars,
    # Proxy settings if configured
    var.proxy_settings != null ? concat([
      {
        name  = "CONTRAST__API__PROXY__ENABLE"
        value = "true"
      }],
      var.proxy_settings.url != "" ? [
        {
          name  = "CONTRAST__API__PROXY__URL"
          value = var.proxy_settings.url
        }] : [
        {
          name  = "CONTRAST__API__PROXY__HOST"
          value = var.proxy_settings.host
        },
        {
          name  = "CONTRAST__API__PROXY__PORT"
          value = tostring(var.proxy_settings.port)
        },
        {
          name  = "CONTRAST__API__PROXY__SCHEME"
          value = var.proxy_settings.scheme
      }],
      var.proxy_settings.username != "" ? [
        {
          name  = "CONTRAST__API__PROXY__USER"
          value = var.proxy_settings.username
      }] : [],
      var.proxy_settings.password != "" ? [
        {
          name  = "CONTRAST__API__PROXY__PASS"
          value = var.proxy_settings.password
      }] : [],
      var.proxy_settings.auth_type != "" ? [
        {
          name  = "CONTRAST__API__PROXY__AUTH_TYPE"
          value = var.proxy_settings.auth_type
    }] : []) : []
  ) : local.base_contrast_env_vars

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
