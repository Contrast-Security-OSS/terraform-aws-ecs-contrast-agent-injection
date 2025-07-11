# Contributing to Terraform AWS ECS Contrast Agent Injection

Thank you for your interest in contributing to this Terraform module! We welcome contributions from the community.

## Getting Started

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [terraform-docs](https://terraform-docs.io/) (for documentation generation)
- [tflint](https://github.com/terraform-linters/tflint) (for linting)
- [checkov](https://www.checkov.io/) (for security scanning)
- AWS CLI configured with appropriate credentials
- Make (for automation tasks)

### Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Contrast-Security-OSS/terraform-aws-ecs-contrast-agent-injection.git
   cd ecs-contrast-agent-injection
   ```

2. Install development tools:
   ```bash
   make check-prereqs
   ```

3. Initialize and validate:
   ```bash
   make validate
   ```

## Development Workflow

### Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes to the module

3. Format code:
   ```bash
   make fmt
   ```

4. Run tests:
   ```bash
   cd terraform-module
   terraform test
   ```

5. Run security scans:
   ```bash
   make security-module
   ```

6. Update documentation:
   ```bash
   make docs
   ```

### Testing

This module uses Terraform's native testing framework. Tests are located in the `terraform-module/tests/` directory.

#### Running Tests

```bash
# Run all tests
cd terraform-module
terraform test

# Run specific test file
terraform test tests/agent_enabled_basic.tftest.hcl

# Run tests with verbose output
terraform test -verbose
```

#### Test Structure

- `agent_disabled.tftest.hcl` - Tests when agent is disabled
- `agent_enabled_basic.tftest.hcl` - Basic enabled configuration tests
- `custom_configuration.tftest.hcl` - Custom configuration scenarios
- `proxy_configuration.tftest.hcl` - Proxy setting tests
- `integration_test.tftest.hcl` - Complete integration scenarios
- `validation_edge_cases.tftest.hcl` - Edge cases and validation tests

#### Adding New Tests

When adding new features:
1. Add appropriate test cases in the relevant test file
2. Ensure all existing tests still pass
3. Test both positive and negative scenarios

### Documentation

- Update the README.md for any new features or changes
- Ensure all variables have descriptions
- Ensure all outputs have descriptions
- Run `make docs` to regenerate auto-documentation

### Security

- Run security scans: `make security-module`
- Address any security findings before submitting
- Use `.checkov.baseline` for acceptable security exceptions

## Submitting Changes

### Pull Request Process

1. Ensure all tests pass
2. Ensure security scans pass
3. Update documentation
4. Update CHANGELOG.md following [Keep a Changelog](https://keepachangelog.com/) format
5. Submit a pull request with:
   - Clear description of changes
   - Any breaking changes noted
   - Test coverage for new features

### Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Examples:
- `feat: add proxy authentication support`
- `fix: resolve container dependency ordering`
- `docs: update proxy configuration examples`
- `test: add edge case validation tests`

### Release Process

Releases follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to the module interface
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

## Module Design Principles

### Terraform Best Practices

- Follow [Terraform module standards](https://www.terraform.io/docs/modules/index.html)
- Use proper input validation
- Provide meaningful outputs
- Support conditional resource creation
- Avoid provider configurations in modules

### Security Considerations

- Sensitive variables should be marked `sensitive = true`
- Follow least-privilege principles
- Use secure defaults
- Regular security scanning

### Compatibility

- Support current and previous major Terraform versions
- Support current and previous major AWS provider versions
- Maintain backward compatibility when possible

## Getting Help

- Check existing [Issues](https://github.com/Contrast-Security-OSS/terraform-aws-ecs-contrast-agent-injection/issues)
- Review [Discussions](https://github.com/Contrast-Security-OSS/terraform-aws-ecs-contrast-agent-injection/discussions)
- Ask questions in issues with the `question` label

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
