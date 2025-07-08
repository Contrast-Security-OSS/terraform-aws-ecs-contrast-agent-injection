#!/bin/bash

# Test automation script for ECS Contrast Sidecar
# This script provides comprehensive testing capabilities for different environments

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform-module"
EXAMPLES_DIR="$SCRIPT_DIR/../examples"

# Default values
TEST_TYPES="unit,integration,e2e"
PARALLEL_JOBS=4
TIMEOUT="60m"
CLEANUP=true
VERBOSE=false
REGION="us-east-1"
KEEP_RESOURCES=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test automation script for ECS Contrast Sidecar

OPTIONS:
    -t, --test-types TYPE     Test types to run (unit,integration,e2e) [default: unit,integration,e2e]
    -p, --parallel JOBS       Number of parallel jobs [default: 4]
    -T, --timeout DURATION    Test timeout [default: 60m]
    -r, --region REGION       AWS region [default: us-east-1]
    -k, --keep-resources      Keep resources after test failure
    -v, --verbose             Verbose output
    --cleanup                 Clean up test resources and exit
    --cleanup-force           Force cleanup of all test resources and exit
    -h, --help                Show this help

EXAMPLES:
    $0                        # Run all tests
    $0 -t unit                # Run only unit tests
    $0 -t e2e -p 1            # Run e2e tests with no parallelization
    $0 -k -v                  # Keep resources and verbose output

ENVIRONMENT VARIABLES:
    CONTRAST_API_KEY          Contrast API key (required for integration/e2e tests)
    CONTRAST_SERVICE_KEY      Contrast service key (required for integration/e2e tests)
    CONTRAST_USER_NAME        Contrast user name (required for integration/e2e tests)
    CONTRAST_API_URL          Contrast API URL [default: https://app.contrastsecurity.com/Contrast]
    AWS_REGION                AWS region [default: us-east-1]
    TEST_TIMEOUT              Test timeout [default: 60m]
    PARALLEL_TESTS            Number of parallel tests [default: 4]
    KEEP_RESOURCES            Keep resources after test failure [default: false]
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--test-types)
            TEST_TYPES="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        -T|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -k|--keep-resources)
            KEEP_RESOURCES=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --cleanup)
            cleanup_test_resources
            exit 0
            ;;
        --cleanup-force)
            cleanup_test_resources_force
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Setup environment variables
export AWS_DEFAULT_REGION=${AWS_REGION:-$REGION}
export AWS_REGION=${AWS_REGION:-$REGION}
export TEST_TIMEOUT=${TEST_TIMEOUT:-$TIMEOUT}
export PARALLEL_TESTS=${PARALLEL_TESTS:-$PARALLEL_JOBS}
export KEEP_RESOURCES=${KEEP_RESOURCES}

if [ "$VERBOSE" = true ]; then
    export TF_LOG=DEBUG
    export TERRATEST_LOG_LEVEL=DEBUG
fi

# Prerequisites check
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for required tools
    local required_tools=("go" "terraform" "aws")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is required but not installed"
            exit 1
        fi
    done
    
    # Check Go version
    local go_version=$(go version | grep -o 'go[0-9]\+\.[0-9]\+' | sed 's/go//')
    local go_major=$(echo "$go_version" | cut -d. -f1)
    local go_minor=$(echo "$go_version" | cut -d. -f2)
    
    if [ "$go_major" -lt 1 ] || [ "$go_major" -eq 1 -a "$go_minor" -lt 21 ]; then
        log_error "Go 1.21 or higher is required (found: $go_version)"
        exit 1
    fi
    
    # Check Terraform version
    local tf_version=$(terraform version | head -n1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/v//')
    local tf_major=$(echo "$tf_version" | cut -d. -f1)
    local tf_minor=$(echo "$tf_version" | cut -d. -f2)
    
    if [ "$tf_major" -lt 1 ] || [ "$tf_major" -eq 1 -a "$tf_minor" -lt 0 ]; then
        log_error "Terraform 1.0 or higher is required (found: $tf_version)"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check Contrast credentials for integration/e2e tests
    if [[ "$TEST_TYPES" == *"integration"* ]] || [[ "$TEST_TYPES" == *"e2e"* ]]; then
        if [ -z "$CONTRAST_API_KEY" ] || [ -z "$CONTRAST_SERVICE_KEY" ] || [ -z "$CONTRAST_USER_NAME" ]; then
            log_error "Contrast credentials are required for integration/e2e tests"
            log_error "Set CONTRAST_API_KEY, CONTRAST_SERVICE_KEY, and CONTRAST_USER_NAME environment variables"
            exit 1
        fi
    fi
    
    log_success "Prerequisites check passed"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Create test output directory
    mkdir -p "$TEST_DIR/test-output"
    
    # Initialize Go modules
    cd "$TEST_DIR"
    if [ ! -f go.mod ]; then
        log_error "go.mod not found in test directory"
        exit 1
    fi
    
    # Download dependencies
    go mod tidy
    go mod download
    
    log_success "Test environment setup complete"
}

# Run unit tests
run_unit_tests() {
    log_info "Running unit tests..."
    
    cd "$TEST_DIR"
    
    if [ "$VERBOSE" = true ]; then
        go test -v -timeout "$TIMEOUT" -parallel "$PARALLEL_JOBS" ./unit/... 2>&1 | tee "$TEST_DIR/test-output/unit-tests.log"
    else
        go test -timeout "$TIMEOUT" -parallel "$PARALLEL_JOBS" ./unit/... 2>&1 | tee "$TEST_DIR/test-output/unit-tests.log"
    fi
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Unit tests passed"
    else
        log_error "Unit tests failed"
        return 1
    fi
}

# Run integration tests
run_integration_tests() {
    log_info "Running integration tests..."
    
    cd "$TEST_DIR"
    
    if [ "$VERBOSE" = true ]; then
        go test -v -timeout "$TIMEOUT" -parallel "$PARALLEL_JOBS" ./integration/... 2>&1 | tee "$TEST_DIR/test-output/integration-tests.log"
    else
        go test -timeout "$TIMEOUT" -parallel "$PARALLEL_JOBS" ./integration/... 2>&1 | tee "$TEST_DIR/test-output/integration-tests.log"
    fi
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Integration tests passed"
    else
        log_error "Integration tests failed"
        return 1
    fi
}

# Run e2e tests
run_e2e_tests() {
    log_info "Running e2e tests..."
    
    cd "$TEST_DIR"
    
    # Run basic e2e tests
    if [ "$VERBOSE" = true ]; then
        go test -v -timeout "$TIMEOUT" -parallel "$PARALLEL_JOBS" ./e2e/... 2>&1 | tee "$TEST_DIR/test-output/e2e-tests.log"
    else
        go test -timeout "$TIMEOUT" -parallel "$PARALLEL_JOBS" ./e2e/... 2>&1 | tee "$TEST_DIR/test-output/e2e-tests.log"
    fi
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "E2E tests passed"
    else
        log_error "E2E tests failed"
        return 1
    fi
}

# Run specific test by name
run_specific_test() {
    local test_name="$1"
    log_info "Running specific test: $test_name"
    
    cd "$TEST_DIR"
    
    if [ "$VERBOSE" = true ]; then
        go test -v -timeout "$TIMEOUT" -run "$test_name" ./... 2>&1 | tee "$TEST_DIR/test-output/specific-test.log"
    else
        go test -timeout "$TIMEOUT" -run "$test_name" ./... 2>&1 | tee "$TEST_DIR/test-output/specific-test.log"
    fi
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Specific test passed: $test_name"
    else
        log_error "Specific test failed: $test_name"
        return 1
    fi
}

# Cleanup test resources
cleanup_test_resources() {
    if [ "$KEEP_RESOURCES" = true ]; then
        log_warning "Keeping resources as requested"
        return
    fi
    
    log_info "Cleaning up test resources..."
    
    # Use the dedicated cleanup script
    "$SCRIPT_DIR/cleanup-resources.sh" --region "$REGION" --prefix "test-" --max-age 1 --force
    
    log_success "Cleanup complete"
}

# Force cleanup of all test resources
cleanup_test_resources_force() {
    log_warning "Force cleaning up ALL test resources..."
    log_warning "This will delete ALL resources with 'test-' prefix regardless of age"
    
    # Use the dedicated cleanup script with more aggressive settings
    "$SCRIPT_DIR/cleanup-resources.sh" --region "$REGION" --prefix "test-" --max-age 0 --force
    
    log_success "Force cleanup complete"
}

# Generate test report
generate_test_report() {
    log_info "Generating test report..."
    
    local report_file="$TEST_DIR/test-output/test-report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>ECS Contrast Sidecar Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007cba; }
        .success { border-left-color: #28a745; }
        .failure { border-left-color: #dc3545; }
        .warning { border-left-color: #ffc107; }
        pre { background-color: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>ECS Contrast Sidecar Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Region: $AWS_REGION</p>
        <p>Test Types: $TEST_TYPES</p>
    </div>
EOF
    
    # Add test results to report
    for test_type in $(echo "$TEST_TYPES" | tr ',' ' '); do
        local log_file="$TEST_DIR/test-output/${test_type}-tests.log"
        if [ -f "$log_file" ]; then
            echo "    <div class='section'>" >> "$report_file"
            echo "        <h2>$test_type Tests</h2>" >> "$report_file"
            echo "        <pre>" >> "$report_file"
            cat "$log_file" >> "$report_file"
            echo "        </pre>" >> "$report_file"
            echo "    </div>" >> "$report_file"
        fi
    done
    
    echo "</body></html>" >> "$report_file"
    
    log_success "Test report generated: $report_file"
}

# Main execution
main() {
    log_info "Starting ECS Contrast Sidecar test automation"
    log_info "Test types: $TEST_TYPES"
    log_info "Parallel jobs: $PARALLEL_JOBS"
    log_info "Timeout: $TIMEOUT"
    log_info "Region: $AWS_REGION"
    
    # Setup
    check_prerequisites
    setup_test_environment
    
    # Run tests
    local failed_tests=()
    
    for test_type in $(echo "$TEST_TYPES" | tr ',' ' '); do
        case $test_type in
            unit)
                if ! run_unit_tests; then
                    failed_tests+=("unit")
                fi
                ;;
            integration)
                if ! run_integration_tests; then
                    failed_tests+=("integration")
                fi
                ;;
            e2e)
                if ! run_e2e_tests; then
                    failed_tests+=("e2e")
                fi
                ;;
            *)
                log_error "Unknown test type: $test_type"
                exit 1
                ;;
        esac
    done
    
    # Generate report
    generate_test_report
    
    # Cleanup
    cleanup_test_resources
    
    # Summary
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Failed test types: ${failed_tests[*]}"
        exit 1
    fi
}

# Execute main function
main "$@"
