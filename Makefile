# Makefile for ECS Contrast Agent Injection

.PHONY: help init validate plan apply destroy clean test docs docker fmt security security-module security-module-detailed security-module-baseline install-tools check-prereqs
.PHONY: test-setup test-unit test-integration test-e2e test-all test-cleanup test-cleanup-force test-cleanup-old test-cleanup-dry-run test-coverage test-quick
.PHONY: test-proxy test-performance test-stability test-multi-region test-chaos test-upgrade
.PHONY: ci-test ci-test-full dev-setup lint-terraform check-env debug-test

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
	@echo "Testing:"
	@echo "  test-setup        - Setup test environment"
	@echo "  test-unit         - Run unit tests"
	@echo "  test-integration  - Run integration tests"
	@echo "  test-e2e          - Run end-to-end tests"
	@echo "  test-all          - Run all tests"
	@echo "  test-quick        - Run quick tests (unit only)"
	@echo "  test-coverage     - Run tests with coverage"
	@echo "  test-cleanup      - Clean up test resources"
	@echo "  test-cleanup-force - Force cleanup of all test resources"
	@echo "  test-cleanup-old   - Clean up test resources older than 1 hour"
	@echo "  test-cleanup-dry-run - Show what test resources would be cleaned up"
	@echo ""
	@echo "Specialized Tests:"
	@echo "  test-proxy        - Run proxy configuration tests"
	@echo "  test-performance  - Run performance tests"
	@echo "  test-stability    - Run stability tests"
	@echo "  test-multi-region - Run multi-region tests"
	@echo "  test-chaos        - Run chaos engineering tests"
	@echo "  test-upgrade      - Run version upgrade tests"
	@echo ""
	@echo "Development:"
	@echo "  dev-setup         - Setup development environment"
	@echo "  lint-terraform    - Run Terraform linting"
	@echo "  check-env         - Check environment variables"
	@echo "  debug-test        - Run specific test with debugging"
	@echo ""
	@echo "CI/CD:"
	@echo "  ci-test          - Run CI tests (unit + integration)"
	@echo "  ci-test-full     - Run full CI test suite"
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

# ============================================================================
# COMPREHENSIVE TESTING TARGETS
# ============================================================================

# Test configuration
TEST_DIR := test
TEST_TIMEOUT := 60m
PARALLEL_JOBS := 4
AWS_REGION := us-east-1

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# Test setup and environment
test-setup: ## Setup test environment and dependencies
	@echo "$(GREEN)Setting up test environment...$(NC)"
	@cd $(TEST_DIR) && go mod tidy && go mod download
	@echo "$(GREEN)Test environment setup complete$(NC)"

dev-setup: ## Setup development environment with tools
	@echo "$(GREEN)Setting up development environment...$(NC)"
	@cd $(TEST_DIR) && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@cd $(TEST_DIR) && go install golang.org/x/vuln/cmd/govulncheck@latest
	@echo "$(GREEN)Development environment setup complete$(NC)"

# Core test targets
test-unit: ## Run unit tests
	@echo "$(GREEN)Running unit tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -parallel $(PARALLEL_JOBS) -v ./unit/...

test-integration: ## Run integration tests
	@echo "$(GREEN)Running integration tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -parallel $(PARALLEL_JOBS) -v ./integration/...

test-e2e: ## Run end-to-end tests
	@echo "$(GREEN)Running e2e tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -parallel $(PARALLEL_JOBS) -v ./e2e/...

test-all: test-unit test-integration test-e2e ## Run all tests
	@echo "$(GREEN)All tests completed successfully$(NC)"

test-quick: ## Run quick tests (unit only)
	@echo "$(GREEN)Running quick tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout 10m -parallel $(PARALLEL_JOBS) -short ./unit/...

test-coverage: ## Run tests with coverage report
	@echo "$(GREEN)Running tests with coverage...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -cover -coverprofile=coverage.out ./...
	@cd $(TEST_DIR) && go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)Coverage report generated: $(TEST_DIR)/coverage.html$(NC)"

# Specialized test targets
test-proxy: ## Run proxy configuration tests
	@echo "$(GREEN)Running proxy configuration tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -v ./e2e -run TestProxyConfiguration

test-performance: ## Run performance tests
	@echo "$(GREEN)Running performance tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -v ./e2e -run TestPerformanceMetrics

test-stability: ## Run stability tests
	@echo "$(GREEN)Running stability tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -v ./e2e -run TestLongRunningStability

test-multi-region: ## Run multi-region tests
	@echo "$(GREEN)Running multi-region tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -v ./e2e -run TestMultiRegionDeployment

test-chaos: ## Run chaos engineering tests
	@echo "$(GREEN)Running chaos engineering tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -v ./e2e -run TestChaosEngineering

test-upgrade: ## Run version upgrade tests
	@echo "$(GREEN)Running version upgrade tests...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -v ./e2e -run TestVersionUpgrade

# Cleanup targets
test-cleanup: ## Clean up test resources
	@echo "$(GREEN)Cleaning up test resources...$(NC)"
	@cd $(TEST_DIR) && ./cleanup-resources.sh --region $(AWS_REGION) --prefix test- --max-age 24 --force
	@echo "$(GREEN)Test cleanup complete$(NC)"

test-cleanup-force: ## Force cleanup of all test resources
	@echo "$(YELLOW)Force cleaning up all test resources...$(NC)"
	@echo "$(RED)This will delete ALL resources with 'test-' prefix regardless of age$(NC)"
	@read -p "Are you sure? (y/N) " -n 1 -r && echo && \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TEST_DIR) && ./cleanup-resources.sh --region $(AWS_REGION) --prefix test- --max-age 0 --force; \
	fi

test-cleanup-old: ## Clean up test resources older than 1 hour
	@echo "$(GREEN)Cleaning up test resources older than 1 hour...$(NC)"
	@cd $(TEST_DIR) && ./cleanup-resources.sh --region $(AWS_REGION) --prefix test- --max-age 1 --force

test-cleanup-dry-run: ## Show what test resources would be cleaned up
	@echo "$(GREEN)Showing test resources that would be cleaned up...$(NC)"
	@cd $(TEST_DIR) && ./cleanup-resources.sh --region $(AWS_REGION) --prefix test- --max-age 24 --dry-run

# CI/CD targets
ci-test: ## Run tests in CI environment
	@echo "$(GREEN)Running CI tests...$(NC)"
	@cd $(TEST_DIR) && ./run-tests.sh --test-types unit,integration --parallel 2 --timeout 30m

ci-test-full: ## Run full test suite in CI environment
	@echo "$(GREEN)Running full CI test suite...$(NC)"
	@cd $(TEST_DIR) && ./run-tests.sh --test-types unit,integration,e2e --parallel 1 --timeout 120m

# Enhanced linting and validation
lint-terraform: ## Run Terraform linting
	@echo "$(GREEN)Running Terraform linting...$(NC)"
	@terraform fmt -check -recursive terraform-module
	@terraform fmt -check -recursive examples
	@terraform fmt -check -recursive $(TEST_DIR)/fixtures

lint-go: ## Run Go linting
	@echo "$(GREEN)Running Go linting...$(NC)"
	@cd $(TEST_DIR) && golangci-lint run ./...

# Environment checks
check-env: ## Check environment variables
	@echo "$(GREEN)Checking environment variables...$(NC)"
	@test -n "$$CONTRAST_API_KEY" || (echo "$(RED)CONTRAST_API_KEY is not set$(NC)" && exit 1)
	@test -n "$$CONTRAST_SERVICE_KEY" || (echo "$(RED)CONTRAST_SERVICE_KEY is not set$(NC)" && exit 1)
	@test -n "$$CONTRAST_USER_NAME" || (echo "$(RED)CONTRAST_USER_NAME is not set$(NC)" && exit 1)
	@echo "$(GREEN)All environment variables are set$(NC)"

# Debug targets
debug-test: ## Run a specific test with debugging
	@echo "$(GREEN)Running test with debugging...$(NC)"
	@read -p "Enter test name: " test_name && \
	cd $(TEST_DIR) && TF_LOG=DEBUG go test -v -run "$$test_name" ./...

debug-infrastructure: ## Debug infrastructure issues
	@echo "$(GREEN)Debugging infrastructure...$(NC)"
	@aws sts get-caller-identity
	@aws ecs list-clusters --query 'clusterArns[?contains(@, `test-`)]'
	@aws ec2 describe-vpcs --filters "Name=tag:Test,Values=true"

# Information targets
test-info: ## Show test system information
	@echo "$(GREEN)Test System Information:$(NC)"
	@echo "Go version: $$(go version)"
	@echo "AWS Region: $(AWS_REGION)"
	@echo "Test Directory: $(TEST_DIR)"
	@echo "Parallel Jobs: $(PARALLEL_JOBS)"
	@echo "Test Timeout: $(TEST_TIMEOUT)"

# Security scanning
security-scan: ## Run security scanning
	@echo "$(GREEN)Running security scans...$(NC)"
	@cd $(TEST_DIR) && govulncheck ./...
	@cd terraform-module && tfsec .
	@cd examples && tfsec .

# Watch targets
watch-tests: ## Watch for changes and run tests
	@echo "$(GREEN)Watching for changes and running tests...$(NC)"
	@cd $(TEST_DIR) && find . -name "*.go" | entr -c make test-unit

# Test specific scenarios
test-basic: ## Run basic functionality test
	@echo "$(GREEN)Running basic functionality test...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -v ./e2e -run TestBasicFunctionality

test-disabled: ## Run disabled agent test
	@echo "$(GREEN)Running disabled agent test...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -v ./e2e -run TestDisabledAgent

test-toggle: ## Run agent toggle test
	@echo "$(GREEN)Running agent toggle test...$(NC)"
	@cd $(TEST_DIR) && go test -timeout $(TEST_TIMEOUT) -v ./e2e -run TestAgentToggle

# Git hooks
install-hooks: ## Install Git hooks for pre-commit testing
	@echo "$(GREEN)Installing Git hooks...$(NC)"
	@echo '#!/bin/bash' > .git/hooks/pre-commit
	@echo 'make lint-terraform lint-go validate' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "$(GREEN)Git hooks installed$(NC)"
