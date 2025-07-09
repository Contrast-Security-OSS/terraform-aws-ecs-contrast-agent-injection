# Terraform AWS ECS Contrast Agent Injection

[![Terraform Registry](https://img.shields.io/badge/terraform-registry-blue.svg)](https://registry.terraform.io/modules/Contrast-Security-OSS/ecs-contrast-agent-injection/aws)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A Terraform module for deploying the Contrast Security agent to Amazon ECS tasks using an agent injection pattern with init containers and shared volumes.

## Description

This module implements a production-ready agent injection pattern for deploying the Contrast Security agent alongside Java applications in AWS ECS using init containers and shared volumes. The pattern enables zero-downtime agent deployment without requiring modifications to application container images.

## Features

- ✅ Zero application image modifications required
- ✅ Supported languages: Java (future support for .NET, Node.js, Python, PHP)
- ✅ Dynamic enable/disable through Terraform variables
- ✅ Environment-based configuration (no config files needed)
- ✅ Support for proxy configurations
- ✅ Automatic server naming based on region
- ✅ Compatible with existing DataDog and other APM agents

## Usage

### Basic Example

```hcl
module "contrast_agent_injection" {
  source  = "Contrast-Security-OSS/ecs-contrast-agent-injection/aws"
  version = "~> 2.0"

  enabled              = true
  agent_type           = "java"
  application_name     = "my-java-service"
  contrast_api_key     = var.contrast_api_key
  contrast_service_key = var.contrast_service_key
  contrast_user_name   = var.contrast_user_name
  environment          = "production"
  log_group_name       = "/ecs/my-app"
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
    for_each = module.contrast_agent_injection.volume_config != null ? [1] : []
    content {
      name = module.contrast_agent_injection.volume_config.name
    }
  }

  container_definitions = jsonencode(concat(
    # Application container
    [{
      name      = "my-app"
      image     = "my-app:latest"
      essential = true
      
      # Add Contrast dependencies
      dependsOn = module.contrast_agent_injection.container_dependencies
      
      # Mount the Contrast volume
      mountPoints = module.contrast_agent_injection.app_mount_points
      
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
        module.contrast_agent_injection.environment_variables,
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
    # Add the Contrast init container
    module.contrast_agent_injection.init_container_definitions
  ))

  tags = {
    Environment = "production"
    Service     = "my-app"
  }
}
```

For complete examples, see the [examples](./examples/) directory.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

No resources are created by this module. It provides data transformations for ECS task definitions.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_type"></a> [agent\_type](#input\_agent\_type) | Type of Contrast agent to deploy (java) | `string` | `"java"` | no |
| <a name="input_additional_env_vars"></a> [additional\_env\_vars](#input\_additional\_env\_vars) | Additional environment variables for Contrast configuration | `map(string)` | `{}` | no |
| <a name="input_application_name"></a> [application\_name](#input\_application\_name) | Name of the application as it will appear in Contrast | `string` | n/a | yes |
| <a name="input_contrast_agent_version"></a> [contrast\_agent\_version](#input\_contrast\_agent\_version) | Specific version of the Contrast agent to use | `string` | `"latest"` | no |
| <a name="input_contrast_api_key"></a> [contrast\_api\_key](#input\_contrast\_api\_key) | API key for Contrast agent authentication | `string` | n/a | yes |
| <a name="input_contrast_api_url"></a> [contrast\_api\_url](#input\_contrast\_api\_url) | URL of the Contrast TeamServer instance | `string` | `"https://app.contrastsecurity.com/Contrast"` | no |
| <a name="input_contrast_log_level"></a> [contrast\_log\_level](#input\_contrast\_log\_level) | Logging verbosity of the Contrast agent | `string` | `"WARN"` | no |
| <a name="input_contrast_service_key"></a> [contrast\_service\_key](#input\_contrast\_service\_key) | Service key for the specific application profile | `string` | n/a | yes |
| <a name="input_contrast_user_name"></a> [contrast\_user\_name](#input\_contrast\_user\_name) | Agent user name for authentication | `string` | n/a | yes |
| <a name="input_enable_stdout_logging"></a> [enable\_stdout\_logging](#input\_enable\_stdout\_logging) | Enable agent logging to stdout for container logs | `bool` | `true` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Enable or disable the Contrast agent injection | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., PRODUCTION, QA, DEVELOPMENT) | `string` | n/a | yes |
| <a name="input_init_container_cpu"></a> [init\_container\_cpu](#input\_init\_container\_cpu) | CPU units for the init container | `number` | `2` | no |
| <a name="input_init_container_image"></a> [init\_container\_image](#input\_init\_container\_image) | Docker image for the Contrast init container | `string` | `"contrast/agent-java:latest"` | no |
| <a name="input_init_container_memory"></a> [init\_container\_memory](#input\_init\_container\_memory) | Memory (in MB) for the init container | `number` | `6` | no |
| <a name="input_log_group_name"></a> [log\_group\_name](#input\_log\_group\_name) | CloudWatch log group name for the init container (must be created externally) | `string` | n/a | yes |
| <a name="input_proxy_settings"></a> [proxy\_settings](#input\_proxy\_settings) | Proxy settings for the Contrast agent | <pre>object({<br>    url       = string<br>    username  = optional(string, "")<br>    password  = optional(string, "")<br>    auth_type = optional(string, "")<br>  })</pre> | `null` | no |
| <a name="input_server_name"></a> [server\_name](#input\_server\_name) | Server name in Contrast UI (defaults to app-name-region if not specified) | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the Contrast configuration | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_activation_env"></a> [agent\_activation\_env](#output\_agent\_activation\_env) | Environment variable name used to activate the agent |
| <a name="output_agent_activation_value"></a> [agent\_activation\_value](#output\_agent\_activation\_value) | Environment variable value used to activate the agent |
| <a name="output_agent_enabled"></a> [agent\_enabled](#output\_agent\_enabled) | Whether the Contrast agent is enabled |
| <a name="output_agent_path"></a> [agent\_path](#output\_agent\_path) | Path where the Contrast agent JAR is mounted in the application container |
| <a name="output_app_mount_points"></a> [app\_mount\_points](#output\_app\_mount\_points) | Mount points for the application container |
| <a name="output_container_dependencies"></a> [container\_dependencies](#output\_container\_dependencies) | Container dependencies for the application container |
| <a name="output_contrast_server_name"></a> [contrast\_server\_name](#output\_contrast\_server\_name) | The computed Contrast server name |
| <a name="output_environment_variables"></a> [environment\_variables](#output\_environment\_variables) | Environment variables for the application container |
| <a name="output_init_container_definitions"></a> [init\_container\_definitions](#output\_init\_container\_definitions) | Container definitions for the Contrast init container |
| <a name="output_init_container_name"></a> [init\_container\_name](#output\_init\_container\_name) | Name of the init container |
| <a name="output_java_tool_options"></a> [java\_tool\_options](#output\_java\_tool\_options) | JAVA\_TOOL\_OPTIONS value for enabling the agent |
| <a name="output_module_version"></a> [module\_version](#output\_module\_version) | Version of the Contrast agent being used |
| <a name="output_proxy_configured"></a> [proxy\_configured](#output\_proxy\_configured) | Whether proxy settings are configured |
| <a name="output_volume_config"></a> [volume\_config](#output\_volume\_config) | Volume configuration for the task definition |
| <a name="output_volume_name"></a> [volume\_name](#output\_volume\_name) | Name of the shared volume |
| <a name="output_agent_type"></a> [agent\_type](#output\_agent\_type) | The type of Contrast agent being used |

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

## Examples

- [Basic Java App](./examples/basic-java-app/) - Complete example with ECS task definition
- [Proxy Configuration](./examples/proxy-configuration/) - Example with corporate proxy settings
- [Multi-Agent Guide](./docs/MULTI_AGENT_GUIDE.md) - Comprehensive guide for all supported agent types

## Testing

This module includes comprehensive tests using Terraform's native testing framework:

```bash
# Run all tests
terraform test

# Run specific test
terraform test -filter=agent_enabled_basic
```

For more information, see the [Testing Guide](./docs/TESTING_GUIDE.md).

## Contributing

Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines.

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](./LICENSE) file for details.