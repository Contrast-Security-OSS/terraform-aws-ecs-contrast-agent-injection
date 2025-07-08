# Troubleshooting Guide

This guide helps diagnose and resolve common issues with the Contrast agent injection deployment.

## Common Issues

### 1. Init Container Fails to Start

**Symptoms:**
- Task fails with "Essential container in task exited"
- Init container shows as "STOPPED" in ECS console

**Diagnosis:**
```bash
# Check CloudWatch logs for the init container
aws logs tail /ecs/contrast-init --follow
```

**Common Causes:**
- Incorrect init container image
- Missing IAM permissions for ECR
- Network issues pulling the image

**Solutions:**
- Verify the init container image exists and is accessible
- Check task execution role has `AmazonECSTaskExecutionRolePolicy`
- Ensure private subnets have NAT gateway or VPC endpoints for ECR

### 2. Agent JAR Not Found

**Symptoms:**
- Application starts but without Contrast agent
- Log shows "Contrast agent file not found"

**Diagnosis:**
```bash
# Check if init container completed successfully
aws ecs describe-tasks \
  --cluster your-cluster \
  --tasks your-task-arn \
  --query 'tasks[0].containers[?name==`contrast-init`]'
```

**Common Causes:**
- Init container didn't complete successfully
- Volume mount misconfiguration
- Incorrect file paths

**Solutions:**
- Verify volume is defined in task definition
- Check mount points match between containers
- Ensure init container exits with status 0

### 3. Application Container Doesn't Wait for Init

**Symptoms:**
- Application starts before agent is copied
- Race condition between containers

**Diagnosis:**
Check the `dependsOn` configuration in the container definition

**Solutions:**
```json
{
  "name": "my-app",
  "dependsOn": [{
    "containerName": "contrast-init",
    "condition": "SUCCESS"
  }]
}
```

### 4. Memory Issues After Agent Deployment

**Symptoms:**
- Container killed with OOMKilled
- Application performance degradation
- Increased GC activity

**Diagnosis:**
```bash
# Monitor memory usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=your-service \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Average
```

**Solutions:**
- Increase task memory allocation
- Adjust JVM heap settings
- Review agent configuration for memory optimization

### 5. Contrast Agent Not Reporting to TeamServer

**Symptoms:**
- Agent starts but application doesn't appear in Contrast
- No vulnerabilities reported

**Diagnosis:**
```bash
# Check application logs for Contrast initialization
aws logs filter-log-events \
  --log-group-name /ecs/my-app \
  --filter-pattern "[Contrast]"
```

**Common Causes:**
- Invalid API credentials
- Network connectivity issues
- Incorrect API URL

**Solutions:**
- Verify all Contrast environment variables are set correctly
- Check security groups allow outbound HTTPS (443)
- Test connectivity to Contrast API from the VPC
- Verify credentials in Contrast TeamServer

### 6. Agent Conflicts with DataDog

**Symptoms:**
- One or both agents fail to initialize
- Performance issues with dual agents

**Diagnosis:**
Check `JAVA_TOOL_OPTIONS` is properly concatenating both agents

**Solutions:**
```bash
# Ensure proper ordering in start.sh
export JAVA_TOOL_OPTIONS="-javaagent:/opt/contrast/java/contrast-agent.jar ${JAVA_TOOL_OPTIONS}"
```

## Debugging Commands

### View Task Definition
```bash
aws ecs describe-task-definition \
  --task-definition your-task-family \
  --query 'taskDefinition.containerDefinitions[*].[name,mountPoints,environment]'
```

### List Running Tasks
```bash
aws ecs list-tasks \
  --cluster your-cluster \
  --service-name your-service
```

### Get Task Details
```bash
aws ecs describe-tasks \
  --cluster your-cluster \
  --tasks task-arn \
  --query 'tasks[0].containers[*].[name,lastStatus,exitCode]'
```

### Check Container Logs
```bash
# Init container logs
aws logs tail /ecs/contrast-init --follow --since 1h

# Application logs
aws logs tail /ecs/my-app --follow --since 1h --filter-pattern "[Contrast]"
```

## Performance Tuning

### JVM Settings for Agents
```bash
# Recommended JVM options for running multiple agents
-XX:MaxRAMPercentage=70.0
-XX:+UseG1GC
-XX:+UseStringDeduplication
-XX:MaxGCPauseMillis=200
```

### Agent Configuration
```bash
# Reduce agent overhead
CONTRAST__AGENT__LOGGER__LEVEL=WARN
CONTRAST__ASSESS__SAMPLING__ENABLE=true
CONTRAST__ASSESS__SAMPLING__PERCENTAGE=50
```

## Emergency Rollback

### Quick Disable via Terraform
```bash
# Set contrast_enabled to false and apply
terraform apply -var="contrast_enabled=false" -auto-approve
```

### Manual Task Definition Update
```bash
# Register a new task definition revision without the init container
aws ecs register-task-definition --cli-input-json file://task-def-no-contrast.json

# Update service to use new revision
aws ecs update-service \
  --cluster your-cluster \
  --service your-service \
  --task-definition your-task-family:new-revision
```

## Getting Help

1. Check CloudWatch Logs for detailed error messages
2. Review Contrast agent logs (if agent starts)
3. Open an issue in this repository with:
   - Task ARN
   - Error messages
   - CloudWatch log excerpts
   - Time of occurrence

## Useful Resources

- [Contrast Documentation](https://docs.contrastsecurity.com)
- [ECS Task Definition Parameters](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html)
- [ECS Container Dependency](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#container_definition_dependson)
