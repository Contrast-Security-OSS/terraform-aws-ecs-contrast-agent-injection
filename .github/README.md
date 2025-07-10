# GitHub Actions for ECS Contrast Agent Injection Module

This directory contains GitHub Actions workflows for testing and publishing the Terraform module to the Terraform Registry.

## Workflows

### 1. Terraform Test (`terraform-test.yml`)
Runs on push to main/develop branches and pull requests to main.

**Jobs:**
- **test**: Validates Terraform configuration and runs tests
  - Terraform format check
  - Terraform validation
  - Terraform test suite
  - tflint linting
- **security**: Runs security scans
  - Trivy vulnerability scanner
  - tfsec security scanner
  - Uploads SARIF results to GitHub Security tab
- **example-test**: Tests the example configurations
  - Validates example Terraform configurations
  - Runs terraform plan (requires AWS credentials)

### 2. Terraform Registry Publish (`terraform-registry-publish.yml`)
Runs on version tags (v*) to publish to the Terraform Registry.

**Jobs:**
- **release**: Creates a GitHub release and publishes to registry
  - Validates Terraform configuration
  - Generates documentation
  - Creates changelog
  - Creates GitHub release
- **notify**: Notifies team of success/failure

### 3. Pre-commit Checks (`pre-commit.yml`)
Runs on push to main/develop branches and pull requests to main.

**Jobs:**
- **pre-commit**: Runs pre-commit hooks and basic checks
  - Pre-commit hooks
  - Terraform formatting
  - Syntax validation
  - Trailing whitespace check
  - Large file detection

## Required Secrets

For the workflows to function properly, you need to configure the following secrets in your GitHub repository:

### For Testing (Optional)
- `AWS_ACCESS_KEY_ID`: AWS access key for testing example configurations
- `AWS_SECRET_ACCESS_KEY`: AWS secret key for testing example configurations

### For Publishing (Required)
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

## Usage

### Running Tests Locally
Before pushing, you can run the same validation locally:

```bash
# Run all CI validation
make ci-validate

# Run individual steps
make fmt
make validate
make security
make test-ci
```

### Creating a Release
To publish a new version to the Terraform Registry:

1. Update the version in `versions.tf` if needed
2. Update the `CHANGELOG.md` with changes
3. Commit and push changes
4. Create and push a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
5. The GitHub Action will automatically create a release and publish to the registry

### Registry Publication
Once published, the module will be available at:
```
https://registry.terraform.io/modules/contrast-security/ecs-contrast-agent-injection/aws
```

And can be used in Terraform configurations like:
```hcl
module "ecs_contrast_agent_injection" {
  source = "contrast-security/ecs-contrast-agent-injection/aws"
  version = "1.0.0"
  
  # Your configuration here
  enabled = true
  application_name = "my-app"
  # ... other variables
}
```

## Best Practices

1. **Always test locally first** using `make ci-validate`
2. **Use semantic versioning** for tags (v1.0.0, v1.0.1, etc.)
3. **Update CHANGELOG.md** before creating releases
4. **Review security scan results** in the GitHub Security tab
5. **Test with examples** to ensure backward compatibility

## Troubleshooting

### Common Issues

1. **Terraform format check fails**: Run `terraform fmt -recursive .`
2. **Security scan failures**: Review and fix security issues, or add to `.checkov.yml` if false positives
3. **Test failures**: Check test files in `tests/` directory
4. **AWS credentials**: Ensure AWS secrets are configured for example testing

### Debug Mode
To enable verbose output in workflows, you can:
1. Add `ACTIONS_STEP_DEBUG=true` to repository secrets
2. Use the workflow dispatch manually with debug options

## Contributing

When contributing to this module:
1. Ensure all tests pass locally
2. Add tests for new features
3. Update documentation
4. Follow semantic versioning for releases
- Pull requests to `main` branch

**Jobs:**
- **terraform-validate**: Validates Terraform configuration and examples
- **terraform-test**: Runs comprehensive Terraform tests using `terraform test`
- **security-scan**: Runs security scans using tfsec
- **lint**: Runs TFLint for Terraform code quality
- **docs-check**: Verifies documentation is up to date

### 🚀 Release Workflow (`release.yml`)

**Triggers:**
- Git tags matching `v*.*.*` (e.g., `v1.0.0`)

**Jobs:**
- **release**: Creates GitHub release and triggers Terraform Registry publication

**To create a release:**
```bash
# Create and push a tag
git tag v1.0.0
git push origin v1.0.0
```

### 🔄 Update Dependencies (`update-dependencies.yml`)

**Triggers:**
- Schedule: Every Monday at 09:00 UTC
- Manual trigger via workflow dispatch

**Jobs:**
- **update-terraform-providers**: Updates Terraform provider dependencies and creates PR if changes are available

### 📚 Documentation Updates (`docs.yml`)

**Triggers:**
- Push to `main` branch when Terraform files change
- Manual trigger via workflow dispatch

**Jobs:**
- **update-docs**: Automatically updates documentation using terraform-docs

### 🔧 Make Commands (`make.yml`)

**Triggers:**
- Manual trigger via workflow dispatch

**Jobs:**
- **make-command**: Runs specified Make commands with proper tooling setup

**Available commands:**
- `help` - Show available Make targets
- `validate` - Validate Terraform configuration
- `fmt` - Format Terraform code
- `security` - Run security scans
- `docs` - Generate documentation
- `clean` - Clean up generated files

## Setup Requirements

### Repository Secrets

No additional secrets are required for basic functionality. The workflows use:
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

### Terraform Registry Publication

For automatic publication to the Terraform Registry:

1. Ensure your repository is public
2. Register your module at [registry.terraform.io](https://registry.terraform.io)
3. Configure the registry to monitor your repository
4. Create releases using semantic versioning tags

### Security Scanning

The workflows include:
- **tfsec**: Terraform static analysis security scanner
- **TFLint**: Terraform linting tool
- **SARIF upload**: Security findings are uploaded to GitHub Security tab

## Usage

### Running Tests Locally

Before pushing changes, run tests locally:

```bash
# Run all validation checks
make ci-validate

# Run specific checks
make validate
make security
make test-ci
```

### Creating a Release

1. Update `CHANGELOG.md` with your changes
2. Create and push a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. The release workflow will automatically create a GitHub release
4. The Terraform Registry will detect the new release within minutes

### Manual Workflow Triggers

Some workflows can be triggered manually:

1. Go to the **Actions** tab in your repository
2. Select the workflow you want to run
3. Click **Run workflow**
4. Choose the branch and any required inputs

## Workflow Status

All workflows include:
- ✅ Proper error handling and status reporting
- 📊 Artifact upload for test results and reports
- 🔒 Security scanning with SARIF upload
- 📱 Clear status checks for pull requests

## Best Practices

1. **Always test locally** before pushing changes
2. **Keep workflows simple** and focused on specific tasks
3. **Use semantic versioning** for releases
4. **Update documentation** when making changes
5. **Monitor workflow runs** and fix any failures promptly

## Troubleshooting

### Common Issues

**Workflow fails with "terraform not found"**
- The `setup-terraform` action handles Terraform installation
- Check if the specified version is available

**Security scan failures**
- Review the security findings in the workflow output
- Update your Terraform code to address security issues
- Consider using `.tfsec` ignore comments for false positives

**Test failures**
- Run `terraform test` locally to reproduce issues
- Check the test artifacts uploaded by the workflow
- Review the test output in the workflow logs

### Getting Help

- Check the [Actions tab](../../actions) for workflow run details
- Review the [Issues page](../../issues) for known problems
- Create a new issue if you encounter problems
