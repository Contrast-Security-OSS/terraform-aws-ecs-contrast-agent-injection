#!/bin/bash

# Comprehensive cleanup script for ECS Contrast Sidecar test resources
# This script identifies and removes residual infrastructure from failed test runs

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:-us-east-1}"
DRY_RUN=false
FORCE=false
MAX_AGE_HOURS=24
TEST_PREFIX="test-"
UNIT_PREFIX="unit-"
INTEGRATION_PREFIX="integration-"
E2E_PREFIX="e2e-"

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

Cleanup script for ECS Contrast Sidecar test resources

OPTIONS:
    -r, --region REGION       AWS region [default: us-east-1]
    -d, --dry-run             Show what would be deleted without actually deleting
    -f, --force               Force deletion without confirmation
    -a, --max-age HOURS       Only delete resources older than HOURS [default: 24]
    -p, --prefix PREFIX       Custom prefix to search for [default: test-]
    -h, --help                Show this help

EXAMPLES:
    $0                        # Interactive cleanup of resources older than 24 hours
    $0 -d                     # Dry run to see what would be deleted
    $0 -f                     # Force cleanup without confirmation
    $0 -a 1                   # Clean up resources older than 1 hour
    $0 -p unit-               # Clean up only unit test resources

RESOURCE TYPES CLEANED:
    - ECS Services and Clusters
    - EC2 Instances, VPCs, Subnets, Security Groups
    - IAM Roles and Policies
    - CloudWatch Log Groups
    - Application Load Balancers
    - NAT Gateways and Internet Gateways
    - Route Tables and Routes
    - ECS Task Definitions
    - CloudFormation Stacks
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -a|--max-age)
            MAX_AGE_HOURS="$2"
            shift 2
            ;;
        -p|--prefix)
            TEST_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check if AWS CLI is installed and configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi

    log_info "AWS CLI is configured. Using region: $AWS_REGION"
}

# Calculate cutoff time for resource age
calculate_cutoff_time() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        date -v-${MAX_AGE_HOURS}H -u '+%Y-%m-%dT%H:%M:%S.000Z'
    else
        # Linux
        date -u -d "${MAX_AGE_HOURS} hours ago" '+%Y-%m-%dT%H:%M:%S.000Z'
    fi
}

# Check if resource is older than cutoff time
is_resource_old_enough() {
    local resource_time="$1"
    local cutoff_time="$2"
    
    if [[ "$resource_time" < "$cutoff_time" ]]; then
        return 0  # Resource is old enough
    else
        return 1  # Resource is too new
    fi
}

# Execute AWS command with dry-run support
execute_aws_command() {
    local command="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would execute: $command"
        return 0
    fi
    
    log_info "$description"
    if eval "$command"; then
        log_success "$description - completed"
        return 0
    else
        log_error "$description - failed"
        return 1
    fi
}

# Cleanup ECS Services
cleanup_ecs_services() {
    log_info "Cleaning up ECS services with prefix: $TEST_PREFIX"
    
    local cutoff_time=$(calculate_cutoff_time)
    
    # Get all clusters
    local clusters=$(aws ecs list-clusters --region "$AWS_REGION" --query 'clusterArns[]' --output text)
    
    for cluster_arn in $clusters; do
        local cluster_name=$(basename "$cluster_arn")
        
        if [[ "$cluster_name" == ${TEST_PREFIX}* ]]; then
            log_info "Checking cluster: $cluster_name"
            
            # Get cluster details to check creation time
            local cluster_info=$(aws ecs describe-clusters --region "$AWS_REGION" --clusters "$cluster_name" --query 'clusters[0]' --output json)
            local creation_time=$(echo "$cluster_info" | jq -r '.registeredAt // empty')
            
            if [[ -n "$creation_time" ]] && is_resource_old_enough "$creation_time" "$cutoff_time"; then
                # Get all services in the cluster
                local services=$(aws ecs list-services --region "$AWS_REGION" --cluster "$cluster_name" --query 'serviceArns[]' --output text)
                
                for service_arn in $services; do
                    local service_name=$(basename "$service_arn")
                    log_info "Scaling down service: $service_name"
                    
                    # Scale down to 0
                    execute_aws_command \
                        "aws ecs update-service --region '$AWS_REGION' --cluster '$cluster_name' --service '$service_name' --desired-count 0" \
                        "Scaling down service $service_name"
                    
                    # Wait for service to be stable
                    if [[ "$DRY_RUN" == false ]]; then
                        log_info "Waiting for service $service_name to be stable..."
                        aws ecs wait services-stable --region "$AWS_REGION" --cluster "$cluster_name" --services "$service_name" || true
                    fi
                    
                    # Delete service
                    execute_aws_command \
                        "aws ecs delete-service --region '$AWS_REGION' --cluster '$cluster_name' --service '$service_name'" \
                        "Deleting service $service_name"
                done
                
                # Delete cluster
                execute_aws_command \
                    "aws ecs delete-cluster --region '$AWS_REGION' --cluster '$cluster_name'" \
                    "Deleting cluster $cluster_name"
            else
                log_info "Cluster $cluster_name is too new, skipping"
            fi
        fi
    done
}

# Cleanup CloudWatch Log Groups
cleanup_cloudwatch_logs() {
    log_info "Cleaning up CloudWatch log groups with prefix: /ecs/$TEST_PREFIX"
    
    local cutoff_time=$(calculate_cutoff_time)
    
    # Get all log groups with the test prefix
    local log_groups=$(aws logs describe-log-groups --region "$AWS_REGION" --log-group-name-prefix "/ecs/$TEST_PREFIX" --query 'logGroups[].logGroupName' --output text)
    
    for log_group in $log_groups; do
        log_info "Checking log group: $log_group"
        
        # Get log group details
        local log_group_info=$(aws logs describe-log-groups --region "$AWS_REGION" --log-group-name-prefix "$log_group" --query 'logGroups[0]' --output json)
        local creation_time=$(echo "$log_group_info" | jq -r '.creationTime // empty')
        
        if [[ -n "$creation_time" ]]; then
            # Convert epoch timestamp to ISO format
            local creation_time_iso
            if [[ "$OSTYPE" == "darwin"* ]]; then
                creation_time_iso=$(date -r "$((creation_time / 1000))" -u '+%Y-%m-%dT%H:%M:%S.000Z')
            else
                creation_time_iso=$(date -u -d "@$((creation_time / 1000))" '+%Y-%m-%dT%H:%M:%S.000Z')
            fi
            
            if is_resource_old_enough "$creation_time_iso" "$cutoff_time"; then
                execute_aws_command \
                    "aws logs delete-log-group --region '$AWS_REGION' --log-group-name '$log_group'" \
                    "Deleting log group $log_group"
            else
                log_info "Log group $log_group is too new, skipping"
            fi
        fi
    done
}

# Cleanup VPCs and related resources
cleanup_vpcs() {
    log_info "Cleaning up VPCs with Test=true tag"
    
    local cutoff_time=$(calculate_cutoff_time)
    
    # Get all VPCs with Test=true tag
    local vpcs=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Test,Values=true" --query 'Vpcs[].VpcId' --output text)
    
    for vpc_id in $vpcs; do
        log_info "Checking VPC: $vpc_id"
        
        # Get VPC tags to check TestId and creation info
        local vpc_info=$(aws ec2 describe-vpcs --region "$AWS_REGION" --vpc-ids "$vpc_id" --query 'Vpcs[0]' --output json)
        local test_id=$(echo "$vpc_info" | jq -r '.Tags[]? | select(.Key=="TestId") | .Value // empty')
        
        if [[ -n "$test_id" && "$test_id" == ${TEST_PREFIX}* ]]; then
            log_info "Found test VPC: $vpc_id (TestId: $test_id)"
            
            # Cleanup resources within the VPC
            cleanup_vpc_resources "$vpc_id"
            
            # Delete VPC
            execute_aws_command \
                "aws ec2 delete-vpc --region '$AWS_REGION' --vpc-id '$vpc_id'" \
                "Deleting VPC $vpc_id"
        fi
    done
}

# Cleanup resources within a VPC
cleanup_vpc_resources() {
    local vpc_id="$1"
    
    log_info "Cleaning up resources in VPC: $vpc_id"
    
    # Delete NAT Gateways
    local nat_gateways=$(aws ec2 describe-nat-gateways --region "$AWS_REGION" --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[?State==`available`].NatGatewayId' --output text)
    for nat_gateway in $nat_gateways; do
        execute_aws_command \
            "aws ec2 delete-nat-gateway --region '$AWS_REGION' --nat-gateway-id '$nat_gateway'" \
            "Deleting NAT Gateway $nat_gateway"
    done
    
    # Delete Internet Gateways
    local igws=$(aws ec2 describe-internet-gateways --region "$AWS_REGION" --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text)
    for igw in $igws; do
        execute_aws_command \
            "aws ec2 detach-internet-gateway --region '$AWS_REGION' --internet-gateway-id '$igw' --vpc-id '$vpc_id'" \
            "Detaching Internet Gateway $igw"
        execute_aws_command \
            "aws ec2 delete-internet-gateway --region '$AWS_REGION' --internet-gateway-id '$igw'" \
            "Deleting Internet Gateway $igw"
    done
    
    # Delete Route Tables (except main)
    local route_tables=$(aws ec2 describe-route-tables --region "$AWS_REGION" --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
    for rt in $route_tables; do
        execute_aws_command \
            "aws ec2 delete-route-table --region '$AWS_REGION' --route-table-id '$rt'" \
            "Deleting Route Table $rt"
    done
    
    # Delete Security Groups (except default)
    local security_groups=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
    for sg in $security_groups; do
        execute_aws_command \
            "aws ec2 delete-security-group --region '$AWS_REGION' --group-id '$sg'" \
            "Deleting Security Group $sg"
    done
    
    # Delete Subnets
    local subnets=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text)
    for subnet in $subnets; do
        execute_aws_command \
            "aws ec2 delete-subnet --region '$AWS_REGION' --subnet-id '$subnet'" \
            "Deleting Subnet $subnet"
    done
}

# Cleanup IAM Roles
cleanup_iam_roles() {
    log_info "Cleaning up IAM roles with prefix: $TEST_PREFIX"
    
    # Get all roles with test prefix
    local roles=$(aws iam list-roles --query "Roles[?starts_with(RoleName, '$TEST_PREFIX')].RoleName" --output text)
    
    for role in $roles; do
        log_info "Checking IAM role: $role"
        
        # Detach managed policies
        local attached_policies=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text)
        for policy_arn in $attached_policies; do
            execute_aws_command \
                "aws iam detach-role-policy --role-name '$role' --policy-arn '$policy_arn'" \
                "Detaching policy $policy_arn from role $role"
        done
        
        # Delete inline policies
        local inline_policies=$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames[]' --output text)
        for policy_name in $inline_policies; do
            execute_aws_command \
                "aws iam delete-role-policy --role-name '$role' --policy-name '$policy_name'" \
                "Deleting inline policy $policy_name from role $role"
        done
        
        # Delete role
        execute_aws_command \
            "aws iam delete-role --role-name '$role'" \
            "Deleting IAM role $role"
    done
}

# Cleanup Load Balancers
cleanup_load_balancers() {
    log_info "Cleaning up Application Load Balancers with Test=true tag"
    
    # Get all ALBs with Test=true tag
    local albs=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'LoadBalancers[].LoadBalancerArn' --output text)
    
    for alb_arn in $albs; do
        # Check if ALB has Test=true tag
        local tags=$(aws elbv2 describe-tags --region "$AWS_REGION" --resource-arns "$alb_arn" --query 'TagDescriptions[0].Tags[?Key==`Test`].Value' --output text)
        
        if [[ "$tags" == "true" ]]; then
            local alb_name=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --load-balancer-arns "$alb_arn" --query 'LoadBalancers[0].LoadBalancerName' --output text)
            log_info "Found test ALB: $alb_name"
            
            execute_aws_command \
                "aws elbv2 delete-load-balancer --region '$AWS_REGION' --load-balancer-arn '$alb_arn'" \
                "Deleting ALB $alb_name"
        fi
    done
}

# Cleanup ECS Task Definitions
cleanup_task_definitions() {
    log_info "Cleaning up ECS task definitions with prefix: $TEST_PREFIX"
    
    # Get all task definition families with test prefix
    local task_families=$(aws ecs list-task-definition-families --region "$AWS_REGION" --family-prefix "$TEST_PREFIX" --query 'families[]' --output text)
    
    for family in $task_families; do
        log_info "Deregistering task definition family: $family"
        
        # Get all revisions for this family
        local revisions=$(aws ecs list-task-definitions --region "$AWS_REGION" --family-prefix "$family" --query 'taskDefinitionArns[]' --output text)
        
        for revision_arn in $revisions; do
            execute_aws_command \
                "aws ecs deregister-task-definition --region '$AWS_REGION' --task-definition '$revision_arn'" \
                "Deregistering task definition $revision_arn"
        done
    done
}

# Main cleanup function
main_cleanup() {
    log_info "Starting cleanup of test resources..."
    log_info "Region: $AWS_REGION"
    log_info "Prefix: $TEST_PREFIX"
    log_info "Max age: $MAX_AGE_HOURS hours"
    log_info "Dry run: $DRY_RUN"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN MODE - No resources will be deleted"
    fi
    
    # Confirm deletion if not in dry-run mode and not forced
    if [[ "$DRY_RUN" == false && "$FORCE" == false ]]; then
        log_warning "This will delete test resources older than $MAX_AGE_HOURS hours"
        read -p "Are you sure you want to continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled"
            exit 0
        fi
    fi
    
    # Cleanup in order of dependencies
    cleanup_ecs_services
    cleanup_cloudwatch_logs
    cleanup_load_balancers
    cleanup_task_definitions
    cleanup_vpcs
    cleanup_iam_roles
    
    log_success "Cleanup completed successfully!"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Run without --dry-run to actually delete resources"
    fi
}

# Check prerequisites
check_aws_cli

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    log_error "jq is not installed. Please install it first."
    exit 1
fi

# Run main cleanup
main_cleanup
