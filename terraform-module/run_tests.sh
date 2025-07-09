#!/bin/bash

# Test runner script for the ECS Contrast Agent Injection Terraform module
# This script runs all tests and provides a summary of results

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="$(dirname "$0")/tests"
MODULE_DIR="$(dirname "$0")"

echo "🧪 Running Terraform tests for ECS Contrast Agent Injection module"
echo "=================================================="

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed or not in PATH${NC}"
    exit 1
fi

# Change to module directory
cd "$MODULE_DIR"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "🔧 Initializing Terraform..."
    terraform init
fi

# Function to run a specific test file
run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .tftest.hcl)
    
    echo -e "\n📋 Running test: ${YELLOW}$test_name${NC}"
    echo "----------------------------------------"
    
    if terraform test -filter="$test_file" -verbose; then
        echo -e "${GREEN}✅ $test_name: PASSED${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name: FAILED${NC}"
        return 1
    fi
}

# Find all test files
test_files=()
for file in "$TEST_DIR"/*.tftest.hcl; do
    if [ -f "$file" ]; then
        test_files+=("$file")
    fi
done

if [ ${#test_files[@]} -eq 0 ]; then
    echo -e "${RED}❌ No test files found in $TEST_DIR${NC}"
    exit 1
fi

echo "Found ${#test_files[@]} test files:"
for file in "${test_files[@]}"; do
    echo "  - $(basename "$file")"
done

# Run all tests
passed=0
failed=0
failed_tests=()

for test_file in "${test_files[@]}"; do
    if run_test "$test_file"; then
        ((passed++))
    else
        ((failed++))
        failed_tests+=("$(basename "$test_file" .tftest.hcl)")
    fi
done

# Summary
echo -e "\n🏁 Test Summary"
echo "=================================================="
echo -e "Total tests: $((passed + failed))"
echo -e "${GREEN}Passed: $passed${NC}"
echo -e "${RED}Failed: $failed${NC}"

if [ $failed -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some tests failed:${NC}"
    for test in "${failed_tests[@]}"; do
        echo -e "  ${RED}- $test${NC}"
    done
    exit 1
fi
