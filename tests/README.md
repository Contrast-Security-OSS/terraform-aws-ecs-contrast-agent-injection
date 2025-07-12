# Terraform Module Testing

This directory contains comprehensive unit tests for the ECS Contrast Agent Injection Terraform module using Terraform's native testing framework.

## Test Structure

The tests are organized into several files, each focusing on specific aspects of the module:

### Test Files

1. **`agent_disabled.tftest.hcl`** - Tests behavior when the Contrast agent is disabled
   - Validates that no containers, volumes, or dependencies are created
   - Ensures outputs return appropriate null/false values
   - Verifies only `CONTRAST_ENABLED=false` environment variable is set

2. **`agent_enabled_basic.tftest.hcl`** - Tests basic enabled configuration
   - Validates init container creation and configuration
   - Tests volume and mount point setup
   - Verifies container dependencies
   - Checks basic environment variables

3. **`custom_configuration.tftest.hcl`** - Tests custom configuration options
   - Custom server names and agent versions
   - Different environments (PRODUCTION, QA, DEVELOPMENT)
   - Custom resource limits and logging settings
   - Additional environment variables

4. **`proxy_configuration.tftest.hcl`** - Tests proxy settings
   - Proxy with authentication
   - Proxy without authentication
   - No proxy configuration

5. **`validation_edge_cases.tftest.hcl`** - Tests edge cases and validation logic
   - Default server name generation
   - Different environment formats
   - Minimal configurations
   - Security optimization settings

6. **`integration_test.tftest.hcl`** - Comprehensive integration test
   - Tests complete configuration with all features enabled
   - Validates all outputs
   - End-to-end functionality verification

7. **`additional_configuration_options.tftest.hcl`** - Tests additional configuration variables
   - Application group, code, version, tags, and metadata
   - Server tags
   - Assessment and inventory tags
   - Session ID and session metadata configuration
   - Empty value handling
   - Complex metadata and tags formatting

8. **`session_configuration_validation.tftest.hcl`** - Tests session configuration validation
   - Mutual exclusivity of session_id and session_metadata
   - Session configuration with CI/CD variables
   - Session configuration outputs validation

9. **`configuration_validation.tftest.hcl`** - Tests input validation rules
   - Variable validation for additional configuration options
   - Case-insensitive environment and log level handling
   - Resource limits validation
   - Boolean variable handling

10. **`token_authentication.tftest.hcl`** - Tests token authentication functionality
   - Token-based authentication validation
   - Token authentication environment variable setup
   - Authentication method detection

11. **`validation_failure_tests.tftest.hcl`** - Tests validation failures with invalid inputs
   - Invalid environment values (should fail)
   - Invalid log levels (should fail)
   - CPU/memory values outside valid ranges (should fail)
   - Invalid agent versions and proxy configurations (should fail)
   - Invalid agent types and proxy auth types (should fail)

12. **`boundary_value_tests.tftest.hcl`** - Tests boundary values and edge cases
   - Minimum and maximum valid CPU/memory values
   - Case variations in environment and log level values
   - Semantic version patterns and multi-digit versions
   - Proxy port boundary values and different schemes
   - All supported proxy authentication types

13. **`output_validation_tests.tftest.hcl`** - Tests output accuracy and completeness
   - Output value accuracy with different configurations
   - Sensitive output handling
   - Output structure validation for containers, volumes, and dependencies
   - Null value handling for disabled and empty configurations
   - Environment variables and mount points output structure

14. **`aws_regional_tests.tftest.hcl`** - Tests AWS-specific and regional functionality
   - Server name generation with region information
   - AWS region data source usage
   - Log configuration with region settings
   - Init container environment variables and mount points
   - Agent image selection and activation configuration
   - Java-specific environment variables and settings

## Running Tests

### Prerequisites

- Terraform 1.6.0 or later (required for native testing)
- Access to AWS (for region data source, but tests use `plan` mode only)

### Running All Tests

Run all tests using Terraform's native test command:

```bash
terraform test
```

This will:
- Run all test files in the `tests/` directory
- Display test results with pass/fail status
- Exit with appropriate status codes

### Running Individual Tests

Run a specific test file:

```bash
terraform test -filter=tests/agent_disabled.tftest.hcl
```

Run with verbose output to see plan details:

```bash
terraform test -filter=tests/agent_enabled_basic.tftest.hcl -verbose
```

### Running Tests in Different Modes

Run tests in parallel (where supported):

```bash
terraform test
```

Generate JUnit XML output for CI/CD:

```bash
terraform test -junit-xml=test-results.xml
```

## Test Coverage

The test suite covers:

### Functional Areas

- ✅ **Agent Enablement**: On/off behavior and outputs
- ✅ **Container Configuration**: Init container setup and resource limits
- ✅ **Volume Management**: Shared volume creation and mount points
- ✅ **Environment Variables**: All Contrast configuration variables
- ✅ **Additional Configuration**: Application group, code, version, tags, metadata
- ✅ **Session Configuration**: Session ID and session metadata with validation
- ✅ **Server Configuration**: Server tags and naming
- ✅ **Assessment & Inventory**: Tags for vulnerabilities and libraries
- ✅ **Proxy Settings**: Different proxy configurations
- ✅ **Logging Configuration**: CloudWatch logging setup
- ✅ **Version Management**: Agent version handling
- ✅ **Authentication**: Token and three-key authentication methods
- ✅ **Dependencies**: Container startup dependencies

### Edge Cases

- ✅ **Minimal Configuration**: Required parameters only
- ✅ **Maximum Configuration**: All optional parameters
- ✅ **Default Values**: Proper fallback behavior
- ✅ **Validation Logic**: Input validation and constraints
- ✅ **Security Settings**: Performance and security optimizations
- ✅ **Empty Values**: Proper handling of empty strings
- ✅ **Case Sensitivity**: Environment and log level handling
- ✅ **Complex Metadata**: Multi-value tags and metadata formatting

### Output Validation

- ✅ **Container Definitions**: Init container specifications
- ✅ **Environment Variables**: Complete environment setup
- ✅ **Mount Points**: Volume mounting configuration
- ✅ **Dependencies**: Container dependency chains
- ✅ **Metadata**: Version and configuration status
- ✅ **Configuration Outputs**: All additional configuration options

## Test Patterns

### Assertion Patterns

The tests use several common assertion patterns:

```hcl
# Check for specific environment variable
assert {
  condition = length([
    for env in local.contrast_env_vars : env
    if env.name == "CONTRAST_ENABLED" && env.value == "true"
  ]) == 1
  error_message = "Should enable Contrast agent"
}

# Check output values
assert {
  condition     = output.agent_enabled == true
  error_message = "Agent should be enabled"
}

# Check array lengths
assert {
  condition     = length(local.init_container) == 1
  error_message = "Should have exactly one init container"
}
```

### Variable Patterns

Tests use the `variables` block in `run` blocks for test-specific configuration:

```hcl
run "test_name" {
  command = plan

  variables {
    enabled = true
    application_name = "test-app"
    # ... other variables
  }

  assert {
    # ... assertions
  }
}
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Terraform Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"
      - name: Run Tests
        run: |
          cd terraform-module
          terraform test
```

### Test Results

Terraform test provides:
- Console output with test results
- Individual test pass/fail status
- Overall summary with counts
- Exit codes for CI/CD integration

## Test Statistics

The current test suite includes:
- **Total Test Files**: 11
- **Total Test Runs**: 66
- **Coverage Areas**: 16 major functional areas
- **Edge Cases**: 8 different edge case scenarios
- **Validation Tests**: 10 input validation scenarios

All tests consistently pass and provide comprehensive coverage of the module's functionality.

## Best Practices

1. **Use Plan Mode**: Tests use `command = plan` to avoid creating real resources
2. **Descriptive Names**: Test names clearly describe what they validate
3. **Isolated Tests**: Each test is independent and can run standalone
4. **Comprehensive Coverage**: Tests cover both happy path and edge cases
5. **Clear Assertions**: Each assertion has a descriptive error message
6. **Organized Structure**: Tests are grouped by functionality

## Troubleshooting

### Common Issues

1. **Terraform Version**: Ensure you're using Terraform 1.6.0+
2. **AWS Credentials**: While tests don't create resources, AWS credentials may be needed for data sources
3. **Test Isolation**: Each test runs independently, but ensure no state conflicts

### Debug Output

For detailed debugging, use verbose mode:

```bash
terraform test -verbose
```

This shows the actual plan output for each run block, helping identify configuration issues.

## Contributing

When adding new features to the module:

1. Add corresponding test cases
2. Follow existing test patterns
3. Ensure tests cover both positive and negative scenarios
4. Update this documentation if needed
5. Run the full test suite before submitting changes
