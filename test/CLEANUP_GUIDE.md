# Test Resource Cleanup System

This document describes the comprehensive cleanup system for the ECS Contrast Sidecar test infrastructure.

## Overview

The cleanup system provides multiple layers of resource cleanup to ensure that test resources don't accumulate and cause cost or quota issues:

1. **Automatic cleanup during tests** - Resources are cleaned up as part of the normal test lifecycle
2. **Manual cleanup scripts** - Scripts to clean up residual resources from failed tests
3. **Scheduled cleanup** - Can be integrated into CI/CD pipelines for regular cleanup
4. **Force cleanup** - Emergency cleanup for when everything else fails

## Components

### 1. Cleanup Script (`cleanup-resources.sh`)

The main cleanup script that can identify and remove test resources across AWS services.

**Usage:**
```bash
# Interactive cleanup of resources older than 24 hours
./test/cleanup-resources.sh

# Dry run to see what would be deleted
./test/cleanup-resources.sh --dry-run

# Force cleanup without confirmation
./test/cleanup-resources.sh --force

# Clean up resources older than 1 hour
./test/cleanup-resources.sh --max-age 1

# Clean up specific prefix
./test/cleanup-resources.sh --prefix unit-
```

**Features:**
- Supports dry-run mode to preview what would be deleted
- Age-based filtering to avoid deleting recent resources
- Comprehensive resource type coverage
- Safe defaults with confirmation prompts
- Detailed logging of cleanup operations

### 2. Makefile Targets

Convenient Make targets for common cleanup operations:

```bash
# Clean up test resources older than 24 hours
make test-cleanup

# Force cleanup of all test resources (with confirmation)
make test-cleanup-force

# Clean up resources older than 1 hour
make test-cleanup-old

# Show what would be cleaned up (dry run)
make test-cleanup-dry-run
```

### 3. Test Helper (`helpers/cleanup.go`)

Go helper functions for cleanup within test code:

```go
// Example usage in a test
func TestMyFeature(t *testing.T) {
    // Create cleanup manager
    cleanupManager := helpers.NewTestCleanupManager(t, "us-east-1", "test-myfeature")
    
    // Register cleanup to run at the end of the test
    defer cleanupManager.Cleanup()
    
    // Register Terraform options for cleanup
    cleanupManager.RegisterTerraformOptions(terraformOptions)
    
    // Your test code here...
}
```

### 4. Enhanced AWS Helper (`helpers/aws_fixed.go`)

Extended AWS helper with comprehensive cleanup capabilities:

```go
// Cleanup by resource prefix
awsHelper.CleanupResourcesByPrefix(t, "test-")

// Cleanup by tags
awsHelper.CleanupResourcesByTags(t, map[string]string{
    "Test": "true",
    "Environment": "test",
})

// Cleanup by age
awsHelper.CleanupResourcesByAge(t, 24*time.Hour)
```

## Resource Types Handled

The cleanup system handles the following AWS resource types:

### ECS Resources
- ECS Services (scaled down first, then deleted)
- ECS Clusters
- ECS Task Definitions (deregistered)

### EC2 Resources
- VPCs and all associated resources:
  - Subnets
  - Security Groups (except default)
  - Route Tables (except main)
  - Internet Gateways
  - NAT Gateways
- EC2 Instances (if tagged appropriately)

### Load Balancers
- Application Load Balancers
- Network Load Balancers
- Target Groups

### IAM Resources
- IAM Roles (with test prefix)
- IAM Policies (detached and deleted)

### CloudWatch
- Log Groups (with test prefix)
- Alarms (if tagged)

## Cleanup Strategies

### 1. Prefix-Based Cleanup

All test resources should use consistent prefixes:
- `test-` - General test resources
- `unit-` - Unit test resources
- `integration-` - Integration test resources
- `e2e-` - End-to-end test resources

### 2. Tag-Based Cleanup

Resources should be tagged with:
- `Test=true` - Identifies test resources
- `TestId=<unique-id>` - Identifies resources from a specific test run
- `Environment=test` - Identifies test environment resources

### 3. Age-Based Cleanup

Resources older than a specified age are cleaned up:
- Default: 24 hours
- Configurable via `--max-age` parameter
- Prevents accidental deletion of recently created resources

## Best Practices

### For Test Authors

1. **Always use the cleanup manager in tests:**
   ```go
   cleanupManager := helpers.NewTestCleanupManager(t, region, uniqueId)
   defer cleanupManager.Cleanup()
   ```

2. **Use consistent resource naming:**
   ```go
   resourceName := cleanupManager.CreateResourceName("webapp")
   ```

3. **Tag all resources appropriately:**
   ```terraform
   tags = {
     Test = "true"
     TestId = var.unique_id
     Environment = "test"
   }
   ```

4. **Register Terraform options:**
   ```go
   cleanupManager.RegisterTerraformOptions(terraformOptions)
   ```

### For CI/CD

1. **Run cleanup before tests:**
   ```bash
   make test-cleanup-old
   ```

2. **Run cleanup after tests (even on failure):**
   ```bash
   make test-all || true
   make test-cleanup-force
   ```

3. **Schedule regular cleanup:**
   ```bash
   # Daily cleanup of resources older than 1 hour
   0 2 * * * cd /path/to/project && make test-cleanup-old
   ```

## Troubleshooting

### Common Issues

1. **Cleanup script fails with permissions error:**
   - Ensure AWS credentials are configured correctly
   - Verify IAM permissions for all resource types

2. **Resources not being cleaned up:**
   - Check that resources have correct tags
   - Verify resource naming follows expected patterns
   - Use dry-run mode to see what would be deleted

3. **Cleanup takes too long:**
   - Some resources (like NAT Gateways) take time to delete
   - Consider running cleanup in background
   - Use parallel cleanup where possible

### Debugging Commands

```bash
# Show current test resources
./test/cleanup-resources.sh --dry-run

# List resources by type
aws ec2 describe-vpcs --filters "Name=tag:Test,Values=true"
aws ecs list-clusters --query 'clusterArns[?contains(@, `test-`)]'
aws logs describe-log-groups --log-group-name-prefix "/ecs/test-"

# Validate cleanup completion
aws ec2 describe-vpcs --filters "Name=tag:Test,Values=true" --query 'Vpcs[].VpcId'
```

## Environment Variables

The cleanup system respects the following environment variables:

- `KEEP_RESOURCES=true` - Skip cleanup (useful for debugging)
- `AWS_REGION` - AWS region for cleanup operations
- `AWS_PROFILE` - AWS profile to use for operations

## Safety Features

1. **Confirmation prompts** - Interactive confirmation before deletion
2. **Dry-run mode** - Preview what would be deleted
3. **Age filtering** - Only delete resources older than specified time
4. **Graceful failure** - Continue cleanup even if some operations fail
5. **Detailed logging** - All cleanup operations are logged

## Integration Examples

### GitHub Actions
```yaml
- name: Cleanup test resources
  run: |
    cd test
    ./cleanup-resources.sh --region us-east-1 --max-age 1 --force
  if: always()
```

### Local Development
```bash
# Add to your ~/.bashrc or ~/.zshrc
alias cleanup-test='cd /path/to/ecs-contrast-sidecar && make test-cleanup-old'
```

## Monitoring and Alerting

Consider setting up monitoring for:
- Resources with `Test=true` tag older than 24 hours
- ECS clusters with `test-` prefix
- CloudWatch log groups with `/ecs/test-` prefix
- High AWS costs in test accounts

This can help identify cleanup failures and prevent resource accumulation.
