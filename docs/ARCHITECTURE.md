# Architecture Documentation: ECS Contrast Agent Injection Module

This document provides a comprehensive overview of the architecture, design patterns, and implementation details of the Terraform AWS ECS Contrast Agent Injection module.

## Table of Contents

1. [Overview](#overview)
2. [Architectural Principles](#architectural-principles)
3. [System Architecture](#system-architecture)
4. [Component Architecture](#component-architecture)
5. [Data Flow](#data-flow)
6. [Module Design](#module-design)
7. [Integration Patterns](#integration-patterns)
8. [Security Architecture](#security-architecture)
9. [Operational Architecture](#operational-architecture)
10. [Future Architecture](#future-architecture)

## Overview

The ECS Contrast Agent Injection module implements a **sidecar injection pattern** using AWS ECS init containers and shared volumes to deploy the Contrast Security agent alongside Java applications without modifying application container images.

### Key Architectural Goals

- **Zero Application Image Modification**: Decouple security tooling from application containers
- **Dynamic Configuration**: Enable/disable agent injection through infrastructure code
- **Multi-Agent Support**: Designed for future expansion to .NET, Node.js, Python, and PHP
- **Production Ready**: Built with enterprise deployment patterns and best practices
- **Separation of Concerns**: Clear boundaries between application and security infrastructure

## Architectural Principles

### 1. Dependency Inversion
The module follows dependency inversion principles by accepting external dependencies rather than creating them:
- CloudWatch log groups (created externally)
- IAM roles and policies (managed by consumer)
- Network resources (VPC, subnets, security groups)

### 2. Conditional Resource Creation
Uses Terraform's conditional logic to enable/disable features:
```hcl
# Resources created only when enabled
init_container = var.enabled ? [container_definition] : []
volume_config = var.enabled ? {name = "contrast-agent-storage"} : null
```

### 3. Data Transformation Module
This is a "data-only" module that transforms inputs into ECS-compatible outputs without creating AWS resources directly.

### 4. Composition over Inheritance
Designed for composition with existing ECS task definitions rather than wrapping them.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            AWS ECS Task Definition                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────┐              ┌─────────────────────────────────┐   │
│  │    Init Container       │              │    Application Container        │   │
│  │   (contrast-init)       │    Step 1    │       (my-java-app)             │   │
│  │                         │─────────────▶│                                 │   │
│  │ • Downloads agent       │   Completes  │ • Waits for init success        │   │
│  │ • Copies to volume      │   with       │ • Mounts volume (read-only)     │   │
│  │ • Sets permissions      │   SUCCESS    │ • Starts with agent attached    │   │
│  │ • Exits (non-essential) │              │ • Runs application              │   │
│  └─────────────────────────┘              └─────────────────────────────────┘   │
│              │                                          │                       │
│              └──────────────┬───────────────────────────┘                       │
│                             │                                                   │
│                   ┌─────────▼─────────┐                                         │
│                   │   Shared Volume   │                                         │
│                   │ (ephemeral memory)│                                         │
│                   │                   │                                         │
│                   │ /opt/contrast/    │                                         │
│                   │   └─java/         │                                         │
│                   │     └─contrast-   │                                         │
│                   │       agent.jar   │                                         │
│                   └───────────────────┘                                         │
│                                                                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                               ECS Service                                       │
│                                                                                 │
│  • Manages task lifecycle                                                       │
│  • Handles rolling deployments                                                  │
│  • Integrates with load balancer                                                │
│  • Monitors container health                                                    │
└─────────────────────────────────────────────────────────────────────────────────┘
         │                                          │                    
         ▼                                          ▼                    
┌─────────────────┐                      ┌─────────────────────┐          
│  CloudWatch     │                      │  Contrast TeamServer│          
│  Logs           │                      │                     │          
│                 │                      │ • Receives telemetry│          
│ • Init logs     │                      │ • Security analysis │          
│ • App logs      │                      │ • Vulnerability data│          
│ • Agent logs    │                      │ • Attack detection  │          
└─────────────────┘                      └─────────────────────┘          
```

## Component Architecture

### 1. Init Container (`contrast-init`)

**Purpose**: Downloads and prepares the Contrast agent for the application container.

**Characteristics**:
- Runs as root (user "0") for file system permissions
- Non-essential container (task continues if it exits successfully)
- Minimal resource allocation (2 CPU units, 6MB memory)
- Exits after completing agent setup

**Key Responsibilities**:
```
1. Download agent JAR from container registry
2. Copy agent to shared volume (/mnt/contrast → /opt/contrast/java)
3. Set appropriate file permissions
4. Exit with status code 0 (SUCCESS)
```

**Image Strategy**:
```
Agent Type  → Container Image
java        → contrast/agent-java:${version}
.net        → contrast/agent-dotnet:${version} (future)
node        → contrast/agent-node:${version} (future)
```

### 2. Application Container

**Purpose**: Runs the business application with the injected Contrast agent.

**Agent Integration**:
- **Dependency**: Waits for init container `SUCCESS` condition
- **Volume Mount**: Read-only mount of agent volume
- **Environment**: `JAVA_TOOL_OPTIONS` with `-javaagent` parameter
- **Startup**: Application JVM loads agent automatically

**Resource Considerations**:
- Add 10-15% CPU overhead for agent
- Add 128-256MB memory for agent JVM heap
- Account for network overhead for telemetry

### 3. Shared Volume

**Type**: Ephemeral volume (memory-backed, not persistent)

**Mount Points**:
```
Init Container:     /mnt/contrast        (read-write)
App Container:      /opt/contrast/java   (read-only)
```

**Security**:
- No host volume binding (security isolation)
- Ephemeral lifecycle (cleaned up with task)
- Read-only for application (prevents tampering)

## Data Flow

### 1. Module Initialization Flow

```
terraform plan/apply
       │
       ▼
┌─────────────────┐
│ Module Inputs   │
│ • enabled=true  │
│ • agent_type    │
│ • credentials   │
│ • configuration │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ Local Variables │
│ • Agent config  │
│ • Volume setup  │
│ • Environment   │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ Module Outputs  │
│ • Init container│
│ • Environment   │
│ • Mount points  │
│ • Dependencies  │
└─────────────────┘
```

### 2. ECS Task Execution Flow

```
ECS Scheduler
     │
     ▼
┌─────────────────────────────────────────────────┐
│              Task Definition                    │
│                                                 │
│  1. Pull init container image                   │
│  2. Create shared volume                        │
│  3. Start init container                        │
│     │                                           │
│     ▼                                           │
│  ┌─────────────────┐                            │
│  │ Init Container  │                            │
│  │ • Copy agent    │                            │
│  │ • Set perms     │                            │
│  │ • Exit SUCCESS  │                            │
│  └─────────────────┘                            │
│     │                                           │
│     ▼                                           │
│  4. dependsOn: SUCCESS ✓                        │
│  5. Start application container                 │
│     │                                           │
│     ▼                                           │
│  ┌─────────────────┐                            │
│  │ App Container   │                            │
│  │ • Mount volume  │                            │
│  │ • Load agent    │                            │
│  │ • Start app     │                            │
│  └─────────────────┘                            │
└─────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────┐
│ Runtime State   │
│ • App running   │
│ • Agent active  │
│ • Telemetry     │
└─────────────────┘
```

### 3. Agent Communication Flow

```
Application JVM
     │ (via agent)
     ▼
┌─────────────────┐
│ Contrast Agent  │
│ • Code analysis │
│ • Attack detect │
│ • Data collect  │
└─────────┬───────┘
          │ (HTTPS)
          ▼
┌─────────────────┐
│ Proxy (optional)│
│ • Auth handling │
│ • Traffic route │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ Contrast        │
│ TeamServer      │
│ • Receive data  │
│ • Process scan  │
│ • Store results │
└─────────────────┘
```

## Module Design

### 1. File Structure

```
├── main.tf              # Core module logic and locals
├── variables.tf         # Input variable definitions
├── outputs.tf           # Module outputs
├── versions.tf          # Provider requirements
├── README.md           # User documentation
├── CHANGELOG.md        # Version history
├── docs/
│   ├── ARCHITECTURE.md # This document
│   ├── BEST_PRACTICES.md
│   ├── MIGRATION.md
│   └── TROUBLESHOOTING.md
├── examples/           # Usage examples
│   └── basic-java-app/
└── tests/              # Terraform tests
    ├── agent_enabled_basic.tftest.hcl
    ├── agent_disabled.tftest.hcl
    ├── custom_configuration.tftest.hcl
    ├── integration_test.tftest.hcl
    ├── proxy_configuration.tftest.hcl
    └── validation_edge_cases.tftest.hcl
```

### 2. Configuration Architecture

**Agent Configuration Hierarchy**:
```hcl
locals {
  agent_configs = {
    java = {
      image_name       = "contrast/agent-java"
      mount_path       = "/opt/contrast/java"
      agent_filename   = "contrast-agent.jar"
      activation_env   = "JAVA_TOOL_OPTIONS"
      activation_value = "-javaagent:/opt/contrast/java/contrast-agent.jar"
      specific_env_vars = [...]
    }
    # Future: .net, node, python, php
  }
}
```

**Environment Variable Strategy**:
```
Base Variables (all agents):
├── CONTRAST__API__URL
├── CONTRAST__API__API_KEY
├── CONTRAST__APPLICATION__NAME
└── ...

Agent-Specific Variables:
├── JAVA_TOOL_OPTIONS (Java)
├── CONTRAST__AGENT__JAVA__STANDALONE_APP_NAME
└── ...

Optional Variables:
├── Proxy settings
├── Custom configuration
└── Additional overrides
```

### 3. Output Architecture

The module produces structured outputs for integration:

```hcl
# Container-related outputs
output "init_container_definitions" {
  description = "JSON for ECS container_definitions"
  value       = local.init_container
}

# Integration outputs
output "app_mount_points" {
  description = "Volume mounts for application container"
  value       = local.app_mount_points
}

output "container_dependencies" {
  description = "dependsOn configuration"
  value       = local.container_dependencies
}

# Configuration outputs
output "environment_variables" {
  description = "Environment vars for application"
  value       = concat(local.contrast_env_vars, local.optional_env_vars)
  sensitive   = true
}
```

## Integration Patterns

### 1. Task Definition Integration

**Pattern**: Dynamic resource composition using Terraform conditionals.

```hcl
resource "aws_ecs_task_definition" "app" {
  # Conditional volume creation
  dynamic "volume" {
    for_each = module.contrast_agent_injection.volume_config != null ? [1] : []
    content {
      name = module.contrast_agent_injection.volume_config.name
    }
  }

  # Container composition
  container_definitions = jsonencode(concat(
    [app_container_definition],
    module.contrast_agent_injection.init_container_definitions
  ))
}
```

### 2. Environment Variable Merging

**Pattern**: Environment variable composition preserving application variables.

```hcl
environment = concat(
  module.contrast_agent_injection.environment_variables,
  local.app_specific_env_vars
)
```

### 3. Multi-Agent Compatibility

**Pattern**: Environment variable concatenation for multiple agents.

```hcl
# In application startup script
if [ "$CONTRAST_ENABLED" = "true" ]; then
    export JAVA_TOOL_OPTIONS="-javaagent:/opt/contrast/java/contrast-agent.jar ${JAVA_TOOL_OPTIONS}"
fi
```

### 4. Proxy Configuration

**Pattern**: Flexible proxy configuration supporting URL or component-based settings.

```hcl
proxy_settings = {
  # Option 1: URL-based (simple)
  url = "https://proxy.company.com:8080"
  
  # Option 2: Component-based (flexible)
  host      = "proxy.company.com"
  port      = 8080
  scheme    = "https"
  auth_type = "Basic"
}
```

## Security Architecture

### 1. Isolation Principles

**Container Isolation**:
- Init container runs as root (required for file operations)
- Application container can run as non-root
- No host volume mounts (prevents host access)
- Ephemeral volumes only (no persistent data)

**Network Isolation**:
- Outbound HTTPS only (port 443)
- No inbound connections required
- VPC subnet isolation
- Security group restrictions

**Credential Management**:
```hcl
# Recommended pattern
secrets = [
  {
    name      = "CONTRAST__API__API_KEY"
    valueFrom = aws_secretsmanager_secret.contrast_api_key.arn
  }
]
```

### 2. IAM Security Model

**Task Execution Role** (ECS infrastructure):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
```

**Task Role** (Application runtime):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/ecs/*"
    }
  ]
}
```

### 3. Agent Security

**Communication Security**:
- TLS 1.2+ for all API communication
- Certificate validation
- API key authentication
- Optional proxy authentication (Basic, NTLM, Digest)

**Runtime Security**:
- Agent runs within JVM sandbox
- No elevated privileges required
- Read-only agent files
- Separate agent process space

## Operational Architecture

### 1. Monitoring and Observability

**CloudWatch Integration**:
```
Log Groups:
├── /ecs/contrast-init          # Init container logs
├── /ecs/my-app                 # Application logs
└── /ecs/my-app/contrast        # Agent-specific logs (optional)

Metrics:
├── ECS/ContainerInsights       # Container metrics
├── AWS/ECS                     # Service metrics
└── Custom metrics              # Application metrics
```

**Health Check Strategy**:
```hcl
healthCheck = {
  command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
  interval    = 30
  timeout     = 5
  retries     = 3
  startPeriod = 120  # Increased for agent initialization
}
```

### 2. Deployment Patterns

**Blue-Green Deployment**:
```
1. Deploy new task definition with agent changes
2. Update service with deployment circuit breaker
3. Monitor health checks and metrics
4. Rollback if issues detected
5. Complete deployment on success
```

**Canary Deployment**:
```hcl
deployment_configuration {
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  maximum_percent         = 110  # 10% canary
  minimum_healthy_percent = 90
}
```

### 3. Scaling Considerations

**Resource Scaling**:
- Init container overhead: ~2 CPU units, ~6MB memory
- Agent runtime overhead: ~10-15% CPU, ~128-256MB memory
- Network overhead: ~5-10% for telemetry

**Auto-scaling Adjustments**:
```hcl
resource "aws_appautoscaling_target" "ecs" {
  scale_in_cooldown  = 120  # Increased for agent shutdown
  scale_out_cooldown = 60   # Standard scale-out
}
```

## Future Architecture

### 1. Multi-Language Support

**Planned Agent Support**:
```hcl
agent_configs = {
  java = {
    image_name     = "contrast/agent-java"
    activation_env = "JAVA_TOOL_OPTIONS"
    # ...
  }
  dotnet = {
    image_name     = "contrast/agent-dotnet"
    activation_env = "CORECLR_PROFILER_PATH"
    # ...
  }
  node = {
    image_name     = "contrast/agent-node"
    activation_env = "NODE_OPTIONS"
    # ...
  }
  python = {
    image_name     = "contrast/agent-python"
    activation_env = "PYTHONPATH"
    # ...
  }
}
```

### 2. Advanced Features

**Planned Enhancements**:
- Multiple agent support per container
- Agent version management and automated updates
- Advanced proxy authentication (NTLM, Kerberos)
- Custom agent configuration file support
- Integration with AWS Parameter Store
- Support for ECS Anywhere and EKS on Fargate

### 3. Ecosystem Integration

**Planned Integrations**:
- AWS App Mesh service mesh integration
- AWS X-Ray distributed tracing
- Amazon GuardDuty threat detection
- AWS Config compliance monitoring
- Terraform Cloud/Enterprise integration

## Conclusion

The ECS Contrast Agent Injection module implements a robust, production-ready architecture that separates security concerns from application deployment while maintaining operational simplicity. The design emphasizes:

- **Flexibility**: Easy enable/disable with no application changes
- **Security**: Proper isolation and credential management
- **Scalability**: Designed for enterprise deployment patterns
- **Maintainability**: Clear separation of concerns and comprehensive testing
- **Extensibility**: Architected for future multi-language support

This architecture serves as a foundation for zero-downtime security agent deployment in containerized environments, setting the standard for infrastructure-as-code security tooling integration.
