# E2E Testing Framework for ECS Contrast Agent Sidecar

This directory contains comprehensive end-to-end testing for the Terraform module.

## Test Structure

```
test/
├── e2e/                    # End-to-end tests
│   ├── basic_test.go       # Basic functionality tests
│   ├── proxy_test.go       # Proxy configuration tests
│   ├── rollback_test.go    # Rollback scenario tests
│   └── performance_test.go # Performance and resource tests
├── integration/            # Integration tests
│   ├── aws_test.go         # AWS resource integration tests
│   ├── contrast_test.go    # Contrast API integration tests
│   └── logs_test.go        # CloudWatch logs integration tests
├── unit/                   # Unit tests
│   ├── module_test.go      # Module structure tests
│   ├── outputs_test.go     # Output validation tests
│   └── variables_test.go   # Variable validation tests
├── fixtures/               # Test fixtures
│   ├── basic/             # Basic test configuration
│   ├── proxy/             # Proxy test configuration
│   ├── multi-env/         # Multi-environment test configuration
│   └── disabled/          # Disabled agent test configuration
└── helpers/               # Test helper functions
    ├── aws.go             # AWS helper functions
    ├── contrast.go        # Contrast validation helpers
    └── terraform.go       # Terraform operation helpers
```

## Running Tests

### Prerequisites

1. **Install Go 1.21+**
   ```bash
   go version
   ```

2. **Install Terraform**
   ```bash
   terraform --version
   ```

3. **Configure AWS Credentials**
   ```bash
   aws configure
   # or
   export AWS_ACCESS_KEY_ID=your-access-key
   export AWS_SECRET_ACCESS_KEY=your-secret-key
   export AWS_DEFAULT_REGION=us-east-1
   ```

4. **Set Contrast Credentials**
   ```bash
   export CONTRAST_API_KEY=your-api-key
   export CONTRAST_SERVICE_KEY=your-service-key
   export CONTRAST_USER_NAME=your-user-name
   ```

### Running All Tests

```bash
# Run all tests
make test-all

# Run only unit tests
make test-unit

# Run only integration tests
make test-integration

# Run only e2e tests
make test-e2e

# Run with verbose output
make test-verbose

# Run specific test
go test -v ./e2e -run TestBasicFunctionality
```

### Test Categories

#### Unit Tests
- Validate module structure and configuration
- Test variable validation and defaults
- Verify output calculations
- **Runtime**: ~30 seconds
- **Cost**: Free (no AWS resources)

#### Integration Tests
- Test AWS resource creation/deletion
- Validate CloudWatch logs integration
- Test Contrast API connectivity
- **Runtime**: ~5-10 minutes
- **Cost**: Minimal (short-lived resources)

#### E2E Tests
- Full deployment scenarios
- Agent functionality validation
- Performance testing
- Rollback scenarios
- **Runtime**: ~20-30 minutes
- **Cost**: Moderate (ECS tasks, NAT gateways)

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `AWS_REGION` | AWS region for testing | No | `us-east-1` |
| `CONTRAST_API_KEY` | Contrast API key | Yes | - |
| `CONTRAST_SERVICE_KEY` | Contrast service key | Yes | - |
| `CONTRAST_USER_NAME` | Contrast user name | Yes | - |
| `CONTRAST_API_URL` | Contrast API URL | No | `https://app.contrastsecurity.com/Contrast` |
| `TEST_TIMEOUT` | Test timeout in minutes | No | `30` |
| `KEEP_RESOURCES` | Keep resources after test failure | No | `false` |
| `PARALLEL_TESTS` | Number of parallel test executions | No | `1` |

## Test Scenarios

### Basic Functionality
- ✅ Module deploys successfully with agent enabled
- ✅ Module deploys successfully with agent disabled
- ✅ Init container runs and copies agent JAR
- ✅ Application container mounts agent volume
- ✅ Environment variables are set correctly
- ✅ Container dependencies work properly

### Proxy Configuration
- ✅ Agent works with HTTP proxy
- ✅ Agent works with HTTPS proxy
- ✅ Agent works with authenticated proxy
- ✅ Agent handles proxy failures gracefully

### Multi-Environment
- ✅ Production environment configuration
- ✅ QA environment configuration
- ✅ Development environment configuration
- ✅ Environment-specific server naming

### Rollback Scenarios
- ✅ Disable agent after enabling
- ✅ Rolling update behavior
- ✅ No service disruption during rollback
- ✅ Clean resource cleanup

### Performance Testing
- ✅ Memory usage within expected limits
- ✅ CPU usage within expected limits
- ✅ Agent initialization time
- ✅ Application startup time impact

### Error Handling
- ✅ Invalid Contrast credentials
- ✅ Network connectivity issues
- ✅ Init container failures
- ✅ Volume mount failures

## Cleanup

Tests automatically clean up resources, but you can manually clean up:

```bash
# Clean up all test resources
make test-cleanup

# Force cleanup (removes all resources with test prefix)
make test-cleanup-force
```

## Debugging

### Enable Debug Logging

```bash
export TF_LOG=DEBUG
export TERRATEST_LOG_LEVEL=DEBUG
go test -v ./e2e -run TestBasicFunctionality
```

### Keep Resources for Investigation

```bash
export KEEP_RESOURCES=true
go test -v ./e2e -run TestBasicFunctionality
```

### View Test Logs

```bash
# View test output
tail -f test-output.log

# View Terraform logs
tail -f terraform.log

# View CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/ecs/test-"
```

## CI/CD Integration

The tests are integrated with the CI/CD pipeline:

1. **Pull Request Tests**: Unit and integration tests run on every PR
2. **Nightly Tests**: Full E2E test suite runs nightly
3. **Release Tests**: All tests run before creating releases

## Best Practices

1. **Resource Naming**: All test resources use a `test-` prefix
2. **Cleanup**: Tests clean up resources even on failure
3. **Parallel Execution**: Tests can run in parallel with proper isolation
4. **Timeout Handling**: All tests have appropriate timeouts
5. **Retry Logic**: Network operations have retry logic
6. **Cost Optimization**: Resources are sized for testing, not production

## Troubleshooting

### Common Issues

1. **AWS Permission Errors**
   ```bash
   # Ensure your AWS credentials have sufficient permissions
   aws sts get-caller-identity
   ```

2. **Contrast API Errors**
   ```bash
   # Test Contrast connectivity
   curl -H "API-Key: $CONTRAST_API_KEY" $CONTRAST_API_URL/api/ng/profile
   ```

3. **Test Timeouts**
   ```bash
   # Increase timeout for slow environments
   export TEST_TIMEOUT=60
   ```

4. **Resource Limits**
   ```bash
   # Check AWS service limits
   aws service-quotas list-service-quotas --service-code ecs
   ```

### Getting Help

1. Check the troubleshooting guide: `docs/TROUBLESHOOTING.md`
2. Review test logs in the `test-output/` directory
3. Contact the platform team for assistance
