# Best Practices for ECS Contrast Agent Injection

This document outlines best practices for deploying and managing the Contrast agent using the agent injection pattern in ECS.

## Architecture Best Practices

### 1. Container Organization

**✅ DO:**
- Keep init container minimal (< 150MB)
- Use official Contrast images when possible
- Set resource limits on init container
- Use non-root users in containers

**❌ DON'T:**
- Include unnecessary tools in init container
- Run init container as root
- Mix application code with agent code

### 2. Volume Management

**✅ DO:**
```hcl
volume {
  name = "contrast-agent-storage"
  # Ephemeral volume - no host_path
}
```

**❌ DON'T:**
- Use host volumes (security risk)
- Share volumes between tasks
- Store sensitive data in volumes

### 3. Container Dependencies

**✅ DO:**
```json
{
  "dependsOn": [{
    "containerName": "contrast-init",
    "condition": "SUCCESS"
  }]
}
```

**❌ DON'T:**
- Use "START" condition (race condition risk)
- Chain multiple dependencies
- Create circular dependencies

## Configuration Best Practices

### 1. Environment Variables

**✅ DO:**
- Use environment variables for all configuration
- Namespace variables properly (`CONTRAST__*`)
- Store secrets in AWS Secrets Manager
- Use meaningful variable names

**Example:**
```hcl
environment = [
  {
    name  = "CONTRAST__APPLICATION__NAME"
    value = var.application_name
  },
  {
    name  = "CONTRAST__SERVER__ENVIRONMENT"
    value = var.environment
  }
]
```

**❌ DON'T:**
- Hardcode sensitive values
- Use abbreviated variable names
- Mix Contrast and app configs

### 2. Secret Management

**✅ DO:**
```hcl
# Store in Secrets Manager
resource "aws_secretsmanager_secret" "contrast" {
  name = "contrast-agent-keys"
}

# Reference in task definition
secrets = [
  {
    name      = "CONTRAST__API__API_KEY"
    valueFrom = aws_secretsmanager_secret.contrast.arn
  }
]
```

**❌ DON'T:**
- Store secrets in environment variables
- Commit secrets to git
- Share secrets between environments

### 3. Tagging Strategy

**✅ DO:**
```hcl
tags = {
  Application = "my-app"
  Environment = "production"
  Team        = "backend"
  SecurityTool = "contrast"
  ManagedBy   = "terraform"
}
```

## Deployment Best Practices

### 1. Rollout Strategy

**✅ DO:**
- Start with development environments
- Use canary deployments
- Monitor metrics during rollout
- Have rollback plan ready

**Recommended Progression:**
1. Development (1 week)
2. QA (1 week)  
3. Staging (2 weeks)
4. Production Canary 10% (1 week)
5. Production 100% (1 week)

### 2. Resource Allocation

**Memory Recommendations:**
```hcl
# Add to existing allocations
locals {
  memory_overhead = {
    "256"  = 256   # Double it
    "512"  = 256   # Add 256MB
    "1024" = 512   # Add 512MB
    "2048" = 512   # Add 512MB
  }
}
```

**CPU Recommendations:**
- Init container: 128 CPU units
- Add 10-15% to application CPU

### 3. Monitoring Setup

**Essential Metrics:**
```hcl
# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.app_name}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
}
```

## Operational Best Practices

### 1. Logging Configuration

**✅ DO:**
```json
{
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/ecs/contrast-init",
      "awslogs-region": "us-east-1",
      "awslogs-stream-prefix": "contrast",
      "awslogs-datetime-format": "%Y-%m-%d %H:%M:%S"
    }
  }
}
```

### 2. Health Checks

**Application Health Check:**
```json
{
  "healthCheck": {
    "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
    "interval": 30,
    "timeout": 5,
    "retries": 3,
    "startPeriod": 120  // Increased for agent initialization
  }
}
```

### 3. Auto-scaling Considerations

**✅ DO:**
- Account for agent initialization time
- Adjust scale-in protection
- Monitor during scaling events

**Example:**
```hcl
resource "aws_appautoscaling_target" "ecs" {
  scale_in_cooldown  = 120  # Increased from 60
  scale_out_cooldown = 60
}
```

## Security Best Practices

### 1. IAM Permissions

**Task Execution Role:**
```hcl
data "aws_iam_policy_document" "execution" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "secretsmanager:GetSecretValue"  # For Contrast keys
    ]
    resources = ["*"]
  }
}
```

### 2. Network Security

**Security Group Rules:**
```hcl
resource "aws_security_group_rule" "contrast_egress" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # Or restrict to Contrast IPs
  security_group_id = aws_security_group.app.id
  description       = "Allow HTTPS for Contrast agent"
}
```

### 3. Compliance Considerations

**✅ DO:**
- Document agent deployment in security runbooks
- Include in compliance scanning
- Regular agent version updates
- Monitor for CVEs

## Performance Best Practices

### 1. JVM Tuning

**Recommended JAVA_TOOL_OPTIONS:**
```bash
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=70.0
-XX:+UseG1GC
-XX:+UseStringDeduplication
-XX:+ParallelRefProcEnabled
```

### 2. Agent Configuration

**Performance-Optimized Settings:**
```hcl
additional_env_vars = {
  CONTRAST__ASSESS__SAMPLING__ENABLE     = "true"
  CONTRAST__ASSESS__SAMPLING__PERCENTAGE = "50"
  CONTRAST__AGENT__LOGGER__LEVEL        = "WARN"
  CONTRAST__INVENTORY__ENABLE           = "false"  # If not needed
}
```

### 3. Multi-Agent Coordination

**When Running with DataDog:**
```bash
# Order matters - Contrast first, then DataDog
export JAVA_TOOL_OPTIONS="-javaagent:/opt/contrast/java/contrast-agent.jar -javaagent:/opt/datadog/dd-java-agent.jar"
```

## Maintenance Best Practices

### 1. Version Management

**✅ DO:**
- Pin agent versions in production
- Validate updates in lower environments
- Review release notes
- Plan quarterly updates

**Version Strategy:**
```hcl
variable "contrast_agent_version" {
  default = "3.12.2"  # Pin specific version
  # default = "latest" # Only for development
}
```

### 2. Upgrade Process

1. Review release notes
2. Update version in development
3. Run full test suite
4. Monitor for 24 hours
5. Proceed to next environment

### 3. Emergency Procedures

**Quick Disable:**
```bash
# Via Terraform
terraform apply -var="contrast_enabled=false" -auto-approve

# Via AWS CLI
aws ecs update-service \
  --cluster my-cluster \
  --service my-service \
  --force-new-deployment
```

## Cost Optimization

### 1. Resource Right-Sizing

**Monitor and Adjust:**
```bash
# Check actual usage after 1 week
aws cloudwatch get-metric-statistics \
  --namespace ECS/ContainerInsights \
  --metric-name MemoryReserved \
  --dimensions Name=ServiceName,Value=my-service

# Reduce if overprovisioned
```

### 2. Log Retention

**Cost-Effective Settings:**
```hcl
resource "aws_cloudwatch_log_group" "contrast" {
  name              = "/ecs/contrast-init"
  retention_in_days = 7  # Short retention for init logs
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/my-app"
  retention_in_days = 30  # Standard retention
}
```

## Troubleshooting Quick Reference

| Issue | Check | Solution |
|-------|-------|----------|
| Agent not starting | Init container logs | Verify image accessibility |
| High memory usage | CloudWatch metrics | Increase task memory |
| Not reporting to Contrast | Application logs | Check credentials |
| Slow startup | Task events | Increase health check grace |
| Network errors | VPC flow logs | Check security groups |

## Summary Checklist

Before deploying to production:

- [ ] Tested in all lower environments
- [ ] Resource allocations adjusted
- [ ] Monitoring alerts configured
- [ ] Rollback plan documented
- [ ] Team trained on operations
- [ ] Security review completed
- [ ] Performance baseline established
- [ ] Documentation updated
