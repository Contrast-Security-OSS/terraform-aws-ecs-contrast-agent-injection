# Makefile for ECS Contrast Agent Sidecar

.PHONY: help init validate plan apply destroy clean test docs

# Default target
help:
	@echo "Available targets:"
	@echo "  init      - Initialize Terraform in the example directory"
	@echo "  validate  - Validate Terraform configuration"
	@echo "  plan      - Show Terraform execution plan"
	@echo "  apply     - Apply Terraform configuration"
	@echo "  destroy   - Destroy Terraform resources"
	@echo "  clean     - Clean up generated files"
	@echo "  test      - Run validation tests"
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

# Run tests
test: validate
	@echo "Running Terraform fmt check..."
	terraform fmt -check -recursive .
	@echo "Running tflint..."
	which tflint > /dev/null 2>&1 && tflint --recursive || echo "tflint not installed"
	@echo "All tests passed!"

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

# Lint Jenkins files
lint-jenkins:
	@echo "Linting Jenkins files..."
	which groovy > /dev/null 2>&1 && \
		find jenkins -name "*.groovy" -exec groovy -n {} \; || \
		echo "groovy not installed"
