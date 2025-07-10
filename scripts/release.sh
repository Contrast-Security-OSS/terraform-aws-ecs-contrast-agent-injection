#!/bin/bash
# Release Preparation Script
# This script helps prepare a new release for the Terraform module

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if version argument is provided
if [ $# -eq 0 ]; then
    print_error "Usage: $0 <version>"
    echo "Example: $0 1.0.0"
    exit 1
fi

VERSION=$1
TAG="v$VERSION"

# Validate version format (basic semver check)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format. Use semantic versioning (e.g., 1.0.0)"
    exit 1
fi

echo "🚀 Preparing release $TAG for ECS Contrast Agent Injection module"
echo

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a git repository"
    exit 1
fi

# Check if working directory is clean
if ! git diff-index --quiet HEAD --; then
    print_error "Working directory is not clean. Please commit or stash changes."
    exit 1
fi

# Check if we're on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    print_warning "Current branch is '$CURRENT_BRANCH', not 'main'"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Aborted"
        exit 1
    fi
fi

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
    print_error "Tag $TAG already exists"
    exit 1
fi

print_step "Running pre-release checks..."

# Run validation
print_step "Running Terraform validation..."
if make ci-validate; then
    print_success "All validation checks passed"
else
    print_error "Validation failed. Please fix issues before releasing."
    exit 1
fi

# Check if terraform-docs is installed and generate docs
if command -v terraform-docs &> /dev/null; then
    print_step "Generating documentation..."
    terraform-docs markdown . > TERRAFORM_DOCS.md
    if [ -n "$(git status --porcelain TERRAFORM_DOCS.md)" ]; then
        print_warning "Documentation was updated. Please review and commit changes."
        echo "Modified files:"
        git status --porcelain TERRAFORM_DOCS.md
        read -p "Continue with release? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Aborted"
            exit 1
        fi
    fi
else
    print_warning "terraform-docs not found. Documentation may be outdated."
fi

# Update version in versions.tf if needed
print_step "Checking version in versions.tf..."
if grep -q "required_version" versions.tf; then
    print_success "versions.tf found"
else
    print_warning "versions.tf not found or doesn't specify required_version"
fi

# Show what will be included in release
print_step "Commits since last tag:"
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~10")
git log --oneline "$LAST_TAG"..HEAD

echo
print_step "Ready to create release $TAG"
echo "This will:"
echo "  1. Create and push tag $TAG"
echo "  2. Trigger GitHub Actions workflow"
echo "  3. Publish to Terraform Registry"
echo "  4. Create GitHub release with changelog"
echo

read -p "Proceed with release? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Aborted"
    exit 1
fi

# Create and push tag
print_step "Creating tag $TAG..."
git tag -a "$TAG" -m "Release $TAG"

print_step "Pushing tag to origin..."
git push origin "$TAG"

print_success "Release $TAG created successfully!"
echo
echo "🎉 Release process initiated!"
echo "📋 Next steps:"
echo "  1. Check GitHub Actions: https://github.com/contrast-security/ecs-contrast-agent-injection/actions"
echo "  2. Monitor release creation: https://github.com/contrast-security/ecs-contrast-agent-injection/releases"
echo "  3. Verify module publication: https://registry.terraform.io/modules/contrast-security/ecs-contrast-agent-injection/aws"
echo
echo "📞 If issues occur:"
echo "  - Check workflow logs in GitHub Actions"
echo "  - Use 'gh run rerun' to retry failed workflows"
echo "  - Delete tag if needed: git push --delete origin $TAG && git tag -d $TAG"
