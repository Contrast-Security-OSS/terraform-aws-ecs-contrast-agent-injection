# Terraform Module: ECS Contrast Agent Sidecar

This Terraform module provides a reusable pattern for deploying the Contrast Security agent as a sidecar in AWS ECS tasks.

## Features

- ✅ Zero application image modifications required
- ✅ Dynamic enable/disable through Terraform variables
- ✅ Environment-based configuration (no config files needed)
- ✅ Support for proxy configurations
- ✅ Automatic server naming based on region
- ✅ Compatible with existing DataDog and other APM agents

## Usage

### Basic Example

```hcl
module "contrast_sidecar" {
  source = "../terraform-module"

  enabled              = true
  application_name     = "my-java-service"
  contrast_api_key     = var.contrast_api_key
  contrast_service_key = var.contrast_service_key
  contrast_user_name   = var.contrast_user_name
  environment          = "production"
}
```

### Complete Example with Task Definition

```hcl
resource "aws_ecs_task_definition" "app" {
  family                   = "my-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

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
      name      = "my-app"
      image     = "my-app:latest"
      essential = true
      
      # Add Contrast dependencies
      dependsOn = module.contrast_sidecar.container_dependencies
      
      # Mount the Contrast volume
      mountPoints = module.contrast_sidecar.app_mount_points
      
      # Ports
      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]
      
      # Resource limits (leave room for init container)
      cpu    = 384
      memory = 896
      
      # Environment variables
      environment = concat(
        module.contrast_sidecar.environment_variables,
        [
          {
            name  = "APP_ENV"
            value = "production"
          }
        ]
      )
      
      # Logging
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/my-app"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "app"
        }
      }
    }],
    
    # Contrast init container
    module.contrast_sidecar.init_container_definitions
  ))
}
```

### With Proxy Configuration

```hcl
module "contrast_sidecar" {
  source = "../terraform-module"

  enabled              = true
  application_name     = "my-java-service"
  contrast_api_key     = var.contrast_api_key
  contrast_service_key = var.contrast_service_key
  contrast_user_name   = var.contrast_user_name
  environment          = "production"
  
  # Proxy configuration
  proxy_settings = {
    host     = "proxy.company.com"
    port     = 8080
    username = var.proxy_username
    password = var.proxy_password
  }
}
```

## Important Notes

### CPU and Memory Allocation

When using this module, remember that ECS requires the sum of all container CPU and memory values to not exceed the task limits, even for init containers. The init container uses 128 CPU units and 128 MB memory by default.

**Example for a 512 CPU / 1024 MB task:**
- Task CPU: 512 units
- Task Memory: 1024 MB
- Init container: 128 CPU + 128 MB (runs at startup only)
- Application container: 384 CPU + 896 MB (max available)

Even though the init container only runs at startup, you must account for it in your resource allocation.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `enabled` | Enable or disable the Contrast agent sidecar | `bool` | `false` | no |
| `application_name` | Name of the application as it will appear in Contrast | `string` | - | yes |
| `contrast_api_url` | URL of the Contrast TeamServer instance | `string` | `https://app.contrastsecurity.com` | no |
| `contrast_api_key` | API key for Contrast agent authentication | `string` | - | yes |
| `contrast_service_key` | Service key for the specific application profile | `string` | - | yes |
| `contrast_user_name` | Agent user name for authentication | `string` | - | yes |
| `environment` | Environment name (production, staging, qa, development, test) | `string` | - | yes |
| `server_name` | Server name in Contrast UI | `string` | `""` | no |
| `contrast_log_level` | Logging verbosity (TRACE, DEBUG, INFO, WARN, ERROR) | `string` | `WARN` | no |
| `init_container_image` | Docker image for the Contrast init container | `string` | `contrast/agent-java:latest` | no |
| `init_container_cpu` | CPU units for the init container | `number` | `128` | no |
| `init_container_memory` | Memory (MB) for the init container | `number` | `128` | no |
| `log_group_name` | CloudWatch log group name for init container | `string` | `""` | no |
| `additional_env_vars` | Additional environment variables for Contrast | `map(string)` | `{}` | no |
| `contrast_agent_version` | Specific version of the Contrast agent | `string` | `latest` | no |
| `enable_stdout_logging` | Enable agent logging to stdout | `bool` | `true` | no |
| `log_retention_days` | Number of days to retain CloudWatch logs | `number` | `7` | no |
| `proxy_settings` | Proxy settings for the Contrast agent | `object` | `null` | no |
| `tags` | Tags to apply to the Contrast configuration | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `init_container_definitions` | Container definitions for the Contrast init container |
| `environment_variables` | Environment variables for the application container |
| `app_mount_points` | Mount points for the application container |
| `container_dependencies` | Container dependencies for the application container |
| `volume_config` | Volume configuration for the task definition |
| `agent_enabled` | Whether the Contrast agent is enabled |
| `agent_path` | Path where the Contrast agent JAR is mounted |
| `java_tool_options` | JAVA_TOOL_OPTIONS value for enabling the agent |
| `init_container_name` | Name of the init container |
| `volume_name` | Name of the shared volume |

## Requirements

- Terraform >= 1.0
- AWS Provider >= 4.0

## License

This module is part of Liberty's internal infrastructure toolkit.
