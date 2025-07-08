#!/bin/bash

# Checkov scan script for terraform-module only
# This script runs checkov specifically on the terraform-module directory
# without scanning examples or test configurations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODULE_DIR="$PROJECT_ROOT/terraform-module"

# Default values
OUTPUT_FORMAT="cli"
CREATE_BASELINE=false
SARIF_OUTPUT=false
QUIET=false
VERBOSE=false

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run checkov security scan on terraform-module only

OPTIONS:
    -h, --help              Show this help message
    -o, --output FORMAT     Output format: cli, json, sarif, junit (default: cli)
    -b, --baseline          Create baseline file for suppressing existing issues
    -s, --sarif             Generate SARIF output file
    -q, --quiet             Quiet mode (less verbose output)
    -v, --verbose           Verbose mode (more detailed output)
    --compact               Compact output format
    --no-guide              Don't include fix guidance in output

EXAMPLES:
    $0                      # Basic scan with CLI output
    $0 -s                   # Generate SARIF output file
    $0 -b                   # Create baseline file
    $0 -o json              # JSON output format
    $0 -q --compact         # Quiet, compact output

ENVIRONMENT VARIABLES:
    CHECKOV_LOG_LEVEL       Set log level (DEBUG, INFO, WARNING, ERROR)
    CHECKOV_CONFIG_FILE     Override config file path
EOF
}

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if checkov is installed
    if ! command -v checkov &> /dev/null; then
        log_error "checkov is not installed"
        log_info "Install it with: pip install checkov"
        exit 1
    fi
    
    # Check if terraform-module directory exists
    if [ ! -d "$MODULE_DIR" ]; then
        log_error "terraform-module directory not found: $MODULE_DIR"
        exit 1
    fi
    
    # Check if terraform-module has .tf files
    if ! find "$MODULE_DIR" -name "*.tf" -type f | head -1 | grep -q .; then
        log_error "No Terraform files found in terraform-module directory"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -b|--baseline)
            CREATE_BASELINE=true
            shift
            ;;
        -s|--sarif)
            SARIF_OUTPUT=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --compact)
            COMPACT=true
            shift
            ;;
        --no-guide)
            NO_GUIDE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main function
main() {
    log_info "Starting checkov scan for terraform-module..."
    
    check_prerequisites
    
    # Change to module directory
    cd "$MODULE_DIR"
    
    # Build checkov command
    local checkov_cmd="checkov -d ."
    
    # Add config file if it exists
    if [ -f ".checkov.yml" ]; then
        checkov_cmd="$checkov_cmd --config-file .checkov.yml"
    fi
    
    # Add output format
    checkov_cmd="$checkov_cmd --output $OUTPUT_FORMAT"
    
    # Add SARIF output if requested
    if [ "$SARIF_OUTPUT" = true ]; then
        checkov_cmd="$checkov_cmd --output sarif --sarif-file-name checkov-results.sarif"
        log_info "SARIF output will be saved to: $MODULE_DIR/checkov-results.sarif"
    fi
    
    # Add baseline creation if requested
    if [ "$CREATE_BASELINE" = true ]; then
        checkov_cmd="$checkov_cmd --create-baseline .checkov.baseline"
        log_info "Baseline will be created at: $MODULE_DIR/.checkov.baseline"
    fi
    
    # Add quiet/verbose flags
    if [ "$QUIET" = true ]; then
        checkov_cmd="$checkov_cmd --quiet"
    fi
    
    if [ "$VERBOSE" = true ]; then
        export CHECKOV_LOG_LEVEL=DEBUG
    fi
    
    # Add compact flag if set
    if [ "${COMPACT:-}" = true ]; then
        checkov_cmd="$checkov_cmd --compact"
    fi
    
    # Add no-guide flag if set
    if [ "${NO_GUIDE:-}" = true ]; then
        checkov_cmd="$checkov_cmd --no-guide"
    fi
    
    log_info "Running command: $checkov_cmd"
    log_info "Scanning directory: $MODULE_DIR"
    
    # Run checkov
    local exit_code=0
    eval "$checkov_cmd" || exit_code=$?
    
    # Report results
    if [ $exit_code -eq 0 ]; then
        log_success "Checkov scan completed successfully - no issues found!"
    elif [ $exit_code -eq 1 ]; then
        log_warning "Checkov scan completed with security issues found"
        log_info "Review the output above for details on security findings"
    else
        log_error "Checkov scan failed with exit code: $exit_code"
        exit $exit_code
    fi
    
    # Show output file locations
    if [ "$SARIF_OUTPUT" = true ] && [ -f "checkov-results.sarif" ]; then
        log_info "SARIF results available at: $MODULE_DIR/checkov-results.sarif"
    fi
    
    if [ "$CREATE_BASELINE" = true ] && [ -f ".checkov.baseline" ]; then
        log_info "Baseline file created at: $MODULE_DIR/.checkov.baseline"
        log_info "Add --baseline .checkov.baseline to future scans to suppress existing issues"
    fi
    
    return $exit_code
}

# Run main function
main "$@"
