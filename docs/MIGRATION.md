# Migration Guide: From Embedded Agent to Agent Injection Pattern

This guide helps teams migrate from embedding the Contrast agent in Docker images to using the agent injection pattern.

## Why Migrate?

### Current Approach Problems
- **Update Toil**: Every agent update requires rebuilding all application images
- **Image Bloat**: Agent adds ~100MB to every application image
- **Tight Coupling**: Security tooling mixed with application code
- **Slow Rollouts**: Agent patches blocked by application release cycles

### Agent Injection Benefits
- **Centralized Updates**: Update agent version in one place
- **Smaller Images**: Application images remain lean
- **Separation of Concerns**: Security managed at infrastructure layer
- **Rapid Patches**: Deploy agent updates in minutes, not days

## Migration Steps

### Phase 1: Preparation

#### 1.1 Audit Current Implementation
```bash
# Find Dockerfiles with embedded Contrast agent
find . -name "Dockerfile*" -exec grep -l "contrast" {} \;

# Check current agent versions
docker run --rm your-app:latest ls -la /opt/contrast/
```

#### 1.2 Document Current Configuration
- Agent version in use
- Configuration method (YAML file vs environment variables)
- Custom agent settings
- Memory allocations

#### 1.3 Update Application Startup Scripts
Before:
```bash
#!/bin/sh
# start.sh with embedded agent
java -javaagent:/opt/contrast/contrast.jar -jar app.jar
```

After:
```bash
#!/bin/sh
# start.sh with dynamic injection
if [ "$CONTRAST_ENABLED" = "true" ]; then
    export JAVA_TOOL_OPTIONS="-javaagent:/opt/contrast/java/contrast-agent.jar ${JAVA_TOOL_OPTIONS}"
fi
java -jar app.jar
```

### Phase 2: Infrastructure Setup

#### 2.1 Deploy Terraform Module

> **Note**: The source format has changed from Git URL to Terraform Registry format. This provides better version management and enables automatic updates through Terraform Registry.

```hcl
module "contrast_agent_injection" {
  source  = "Contrast-Security-OSS/ecs-contrast-agent-injection/aws"
  version = "~> 1.0"

  enabled              = false  # Start disabled
  application_name     = "my-app"
  contrast_api_key     = var.contrast_api_key
  contrast_service_key = var.contrast_service_key
  contrast_user_name   = var.contrast_user_name
  environment          = "staging"
}
```

#### 2.2 Update Task Definition
```hcl
resource "aws_ecs_task_definition" "app" {
  # Add volume
  dynamic "volume" {
    for_each = module.contrast_agent_injection.volume_config != null ? [1] : []
    content {
      name = module.contrast_agent_injection.volume_config.name
    }
  }

  container_definitions = jsonencode(concat(
    [{
      name = "app"
      # Remove embedded agent from image
      image = "app:no-agent"

      # Add agent injection configurations
      dependsOn   = module.contrast_agent_injection.container_dependencies
      mountPoints = module.contrast_agent_injection.app_mount_points
      environment = concat(
        module.contrast_agent_injection.environment_variables,
        local.app_env_vars
      )
    }],
    module.contrast_agent_injection.init_container_definitions
  ))
}
```

### Phase 3: Validation

#### 3.1 Deploy to Development Environment
1. Build new application image WITHOUT embedded agent
2. Deploy with `contrast_enabled = false`
3. Verify application works without any agent
4. Enable Contrast agent injection with `contrast_enabled = true`
5. Verify agent initializes and reports to TeamServer

#### 3.2 Validation Checklist
- [ ] Application starts successfully
- [ ] Agent appears in CloudWatch logs
- [ ] Application visible in Contrast TeamServer
- [ ] Memory usage within acceptable limits
- [ ] No performance degradation
- [ ] Existing monitoring still works

### Phase 4: Production Rollout

#### 4.1 Canary Deployment
```hcl
# Start with 10% of instances
resource "aws_ecs_service" "app" {
  deployment_configuration {
    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }

    maximum_percent         = 110  # Only 10% extra during deployment
    minimum_healthy_percent = 90
  }
}
```

#### 4.2 Progressive Rollout
1. Week 1: Deploy to 10% of production instances
2. Week 2: Increase to 50% if metrics are good
3. Week 3: Complete rollout to 100%

#### 4.3 Monitoring During Rollout
```bash
# Monitor error rates
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=TargetGroup,Value=your-tg

# Monitor memory usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=your-service
```

### Phase 5: Cleanup

#### 5.1 Remove Agent from Dockerfiles
```dockerfile
# Remove these lines from Dockerfile
# RUN wget -O /opt/contrast/contrast.jar https://...
# ENV JAVA_TOOL_OPTIONS="-javaagent:/opt/contrast/contrast.jar"
```

#### 5.2 Update CI/CD Pipeline
Remove agent download/installation steps from the build process

#### 5.3 Update Documentation
- Update runbooks
- Update deployment guides
- Archive old agent installation docs

## Rollback Plan

If issues arise during migration:

1. **Quick Rollback**: Set `contrast_enabled = false` and redeploy
2. **Full Rollback**: Deploy previous task definition with embedded agent

```bash
# Get previous task definition
aws ecs describe-task-definition \
  --task-definition my-app:previous-revision > old-task-def.json

# Update service
aws ecs update-service \
  --cluster my-cluster \
  --service my-service \
  --task-definition my-app:previous-revision
```

## Common Migration Issues

### Issue: Different Agent Versions
**Problem**: Embedded agent is an older version than agent injection pattern
**Solution**: Validate all settings migrated correctly, use contrast_security.yaml if needed

### Issue: Resource Constraints
**Problem**: Agent injection pattern uses slightly more memory (init container overhead)
**Solution**: Add 128MB to memory allocation

## Success Metrics

Track these metrics to validate successful migration:

1. **Agent Update Time**: Should drop from days to minutes
2. **Image Build Time**: Should decrease by 20-30%
3. **Image Size**: Should decrease by ~100MB
4. **Deployment Frequency**: Should increase due to easier updates
5. **Security Patch Time**: Time to deploy critical agent updates

## Timeline Example

For a typical application:
- Week 1-2: Preparation and testing
- Week 3-4: Staging deployment and validation
- Week 5-6: Production canary (10%)
- Week 7-8: Production rollout (100%)
- Week 9: Cleanup and documentation

## Support

For migration assistance:
- Review [Troubleshooting Guide](./TROUBLESHOOTING.md)
- Check [Contrast Documentation](https://docs.contrastsecurity.com)
- Open an issue in this repository for guidance
