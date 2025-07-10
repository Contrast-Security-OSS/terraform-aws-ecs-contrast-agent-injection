# Makefile for ECS Contrast Agent Injection

.PHONY: help init validate plan apply destroy clean docs docker fmt security security-module security-module-detailed security-module-baseline install-tools check-prereqs
.PHONY: dev-setup lint-terraform check-env

# Default target
help:
	@echo "Available targets:"
	@echo ""
	@echo "Basic Operations:"
	@echo "  init      - Initialize Terraform in the example directory"
	@echo "  validate  - Validate Terraform configuration"
	@echo "  plan      - Show Terraform execution plan"
	@echo "  apply     - Apply Terraform configuration"
	@echo "  destroy   - Destroy Terraform resources"
	@echo "  clean     - Clean up generated files"
	@echo ""
	@echo "Development:"
	@echo "  dev-setup         - Setup development environment"
	@echo "  lint-terraform    - Run Terraform linting"
	@echo "  check-env         - Check environment variables"
	@echo ""
	@echo "Security:"
	@echo "  security               - Run security scan on entire project"
	@echo "  security-module        - Run security scan on terraform-module only"
	@echo "  security-module-detailed - Run detailed security scan on terraform-module with SARIF output"
	@echo "  security-module-baseline - Create security baseline for terraform-module"
	@echo ""
	@echo "Documentation:"
	@echo "  docs      - Generate documentation"
	@echo "  docker    - Build custom Docker image"

# Initialize Terraform
init:
	cd examples/basic-java-app && terraform init

# Validate Terraform configuration
validate:
	cd terraform-module && terraform init && terraform validate
	cd examples/basic-java-app && terraform init && terraform validate

# Show Terraform plan
plan:
	cd examples/basic-java-app && terraform plan

# Apply Terraform configuration
apply:
	cd examples/basic-java-app && terraform apply

# Destroy Terraform resources
destroy:
	cd examples/basic-java-app && terraform destroy

# Clean up generated files
clean:
	find . -type d -name ".terraform" -exec rm -rf {} +
	find . -type f -name "*.tfstate*" -exec rm -f {} +
	find . -type f -name "*.tfplan" -exec rm -f {} +
	find . -type f -name "*.log" -exec rm -f {} +

# Basic validation
validate:
	cd terraform-module && terraform init && terraform validate
	cd examples/basic-java-app && terraform init && terraform validate
	@echo "Running Terraform fmt check..."
	terraform fmt -check -recursive .
	@echo "Running tflint..."
	which tflint > /dev/null 2>&1 && tflint --recursive || echo "tflint not installed"
	@echo "All validation checks passed!"

# Generate documentation
docs:
	@echo "Generating Terraform module documentation..."
	which terraform-docs > /dev/null 2>&1 && \
		terraform-docs markdown terraform-module > terraform-module/TERRAFORM_DOCS.md || \
		echo "terraform-docs not installed"

# Build Docker image
docker:
	cd docker && docker build -t contrast-init:local .

# Format Terraform files
fmt:
	terraform fmt -recursive .

# Security scan
security:
	@echo "Running security scan..."
	which tfsec > /dev/null 2>&1 && tfsec . || echo "tfsec not installed"
	which checkov > /dev/null 2>&1 && checkov -d . --framework terraform || echo "checkov not installed"

# Security scan for terraform module only
security-module:
	@echo "Running security scan on terraform-module only..."
	which tfsec > /dev/null 2>&1 && tfsec terraform-module/ || echo "tfsec not installed"
	which checkov > /dev/null 2>&1 && checkov -d terraform-module/ --config-file terraform-module/.checkov.yml || echo "checkov not installed"

# Security scan with detailed output for terraform module
security-module-detailed:
	@echo "Running detailed security scan on terraform-module..."
	which checkov > /dev/null 2>&1 && checkov -d terraform-module/ --config-file terraform-module/.checkov.yml --output cli --output sarif --sarif-file-name terraform-module/checkov-results.sarif || echo "checkov not installed"

# Security scan for terraform module with baseline creation
security-module-baseline:
	@echo "Creating security baseline for terraform-module..."
	which checkov > /dev/null 2>&1 && checkov -d terraform-module/ --config-file terraform-module/.checkov.yml --create-baseline terraform-module/.checkov.baseline || echo "checkov not installed"

# Install development tools
install-tools:
	@echo "Installing development tools..."
	@echo "Please install the following tools:"
	@echo "  - terraform"
	@echo "  - tflint"
	@echo "  - terraform-docs"
	@echo "  - tfsec"
	@echo "  - checkov"
	@echo "  - aws-cli"

# Check prerequisites
check-prereqs:
	@echo "Checking prerequisites..."
	@command -v terraform >/dev/null 2>&1 || { echo "terraform is required but not installed."; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "aws-cli is required but not installed."; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "docker is required but not installed."; exit 1; }
	@echo "All prerequisites are installed!"

# Run example with Contrast enabled
run-example-with-contrast:
	cd examples/basic-java-app && \
		terraform apply -var="contrast_enabled=true" -auto-approve

# Run example without Contrast
run-example-no-contrast:
	cd examples/basic-java-app && \
		terraform apply -var="contrast_enabled=false" -auto-approve

# Show module outputs
show-outputs:
	cd examples/basic-java-app && terraform output -json

# Setup development environment with tools
dev-setup: ## Setup development environment with tools
	@echo "Installing development tools..."
	@echo "Please install the following tools:"
	@echo "  - terraform"
	@echo "  - tflint"
	@echo "  - terraform-docs"
	@echo "  - tfsec"
	@echo "  - checkov"
	@echo "  - aws-cli"

# Enhanced linting and validation
lint-terraform: ## Run Terraform linting
	@echo "Running Terraform linting..."
	@terraform fmt -check -recursive terraform-module
	@terraform fmt -check -recursive examples
	@which tflint > /dev/null 2>&1 && tflint --recursive || echo "tflint not installed"

# Environment checks
check-env: ## Check environment variables
	@echo "Checking environment variables..."
	@test -n "$$CONTRAST_API_KEY" || (echo "CONTRAST_API_KEY is not set" && exit 1)
	@test -n "$$CONTRAST_SERVICE_KEY" || (echo "CONTRAST_SERVICE_KEY is not set" && exit 1)
	@test -n "$$CONTRAST_USER_NAME" || (echo "CONTRAST_USER_NAME is not set" && exit 1)
	@echo "All environment variables are set"
