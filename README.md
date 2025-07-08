# ECS Contrast Agent Sidecar

A Terraform module to deploy the Contrast Security agent to Amazon ECS using a sidecar pattern with init containers and shared volumes. This approach allows dynamic agent injection without modifying application container images.

## Overview

This project implements a production-ready sidecar pattern for deploying the Contrast Security agent alongside Java applications in AWS ECS. The pattern uses:

- **Init Container**: A lightweight container that runs before the application to copy the Contrast agent JAR
- **Shared Volume**: An ephemeral volume that shares the agent between containers
- **Dynamic Configuration**: Environment variables for runtime configuration
- **Conditional Deployment**: Terraform-based opt-in/opt-out mechanism

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ECS Task Definition                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────┐    ┌──────────────────────────┐    │
│  │   Init Container    │    │   Application Container  │    │
│  │ (contrast-init)     │    │     (my-java-app)        │    │
│  │                     │    │                          │    │
│  │ 1. Copies agent.jar │───▶│ 2. Mounts agent.jar      │    │
│  │    to shared volume │    │ 3. Runs with -javaagent  │    │
│  └─────────────────────┘    └──────────────────────────┘    │
│             │                            │                  │
│             └────────────┬───────────────┘                  │
│                          │                                  │
│                   Shared Volume                             │
│                (/opt/contrast/java)                         │
└─────────────────────────────────────────────────────────────┘
```

## Benefits

- **Decoupled Architecture**: Agent updates don't require application rebuilds
- **Centralized Management**: Control agent deployment through infrastructure code
- **Zero Application Changes**: No modifications to application Dockerfiles
- **Flexible Configuration**: Environment-based configuration without files
- **Rapid Rollback**: Disable agent instantly through Terraform variables

## Quick Start

### 1. Use the Module

```hcl
module "contrast_sidecar" {
  source = "./terraform-module"

  enabled                 = true
  application_name        = "my-java-app"
  contrast_api_url       = "https://app.contrastsecurity.com"
  contrast_api_key       = var.contrast_api_key
  contrast_service_key   = var.contrast_service_key
  contrast_user_name     = var.contrast_user_name
  environment            = "production"
}
```

### 2. Include in Task Definition

```hcl
resource "aws_ecs_task_definition" "app" {
  family = "my-app"
  
  # Add the Contrast volume
  dynamic "volume" {
    for_each = module.contrast_sidecar.volume_config != null ? [1] : []
    content {
      name = module.contrast_sidecar.volume_config.name
    }
  }
  
  container_definitions = jsonencode(concat(
    # Your application container
    [{
      name      = "my-java-app"
      image     = "my-app:latest"
      essential = true
      
      # Add Contrast dependencies
      dependsOn = module.contrast_sidecar.container_dependencies
      
      # Mount the Contrast volume
      mountPoints = module.contrast_sidecar.app_mount_points
      
      # Include Contrast environment variables
      environment = concat(
        module.contrast_sidecar.environment_variables,
        [
          # Your app-specific environment variables
        ]
      )
    }],
    
    # Add the Contrast init container
    module.contrast_sidecar.init_container_definitions
  ))
}
```

### 3. Update Application Entrypoint

Add to your application's `start.sh`:

```bash
#!/bin/sh

# Contrast Agent Dynamic Injection
if [ "$CONTRAST_ENABLED" = "true" ]; then
  echo "Contrast agent is enabled. Injecting agent into JAVA_TOOL_OPTIONS."
  CONTRAST_AGENT_PATH="/opt/contrast/java/contrast-agent.jar"
  export JAVA_TOOL_OPTIONS="-javaagent:${CONTRAST_AGENT_PATH} ${JAVA_TOOL_OPTIONS}"
  echo "Updated JAVA_TOOL_OPTIONS: ${JAVA_TOOL_OPTIONS}"
fi

# Your existing application startup
exec java -jar /app/my-application.jar "$@"
```

## Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| `contrast_api_url` | Contrast TeamServer URL |
| `contrast_api_key` | API key for authentication |
| `contrast_service_key` | Service key for the application |
| `contrast_user_name` | Agent user name |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enabled` | Enable/disable the Contrast agent | `false` |
| `contrast_agent_version` | Version of the Contrast agent | `latest` |
| `contrast_log_level` | Agent logging level | `WARN` |
| `init_container_image` | Custom init container image | `contrast/agent-java:latest` |

## Resource Management

### Memory Recommendations

For services running both DataDog and Contrast agents:

| Current Memory | Recommended Increase |
|----------------|---------------------|
| 256MB | +256MB (512MB total) |
| 512MB | +256MB (768MB total) |
| 1024MB | +512MB (1536MB total) |

### Monitoring

Monitor these metrics after deployment:
- Container memory utilization
- JVM heap usage and GC frequency
- Application response times
- Agent overhead percentage

## Rollback Plan

To quickly disable the Contrast agent:

1. Set `enabled = false` in your Terraform configuration
2. Apply the Terraform changes
3. Redeploy the service
4. ECS will perform a rolling deployment

Total rollback time: Same as standard deployment time

## Examples

Check the [examples](./examples) directory for:
- Basic Java application setup
- Multi-environment configuration
- Integration with existing monitoring setup

## Support

For issues or questions:
- Check the [Troubleshooting Guide](./docs/TROUBLESHOOTING.md)
- Review [Contrast Documentation](https://docs.contrastsecurity.com)
- Contact your platform team

## License

This module is maintained by Liberty's Platform Engineering team.
