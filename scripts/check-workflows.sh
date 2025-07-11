#!/bin/bash
# GitHub Actions Status Check Script
# This script checks the status of GitHub Actions workflows

set -e

REPO_OWNER="Contrast-Security-OSS"
REPO_NAME="terraform-aws-ecs-contrast-agent-injection"

echo "🔍 Checking GitHub Actions status for $REPO_OWNER/$REPO_NAME..."
echo

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Please install it first:"
    echo "   https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Please authenticate with GitHub CLI first:"
    echo "   gh auth login"
    exit 1
fi

echo "📊 Recent workflow runs:"
gh run list --repo "$REPO_OWNER/$REPO_NAME" --limit 10

echo
echo "📋 Workflow status:"
gh run list --repo "$REPO_OWNER/$REPO_NAME" --limit 5 --json status,conclusion,name,createdAt,htmlUrl \
    --template '{{range .}}{{printf "%-25s" .name}} {{.status}} {{if .conclusion}}({{.conclusion}}){{end}} {{timeago .createdAt}}
{{end}}'

echo
echo "🎯 To view a specific workflow run:"
echo "   gh run view --repo $REPO_OWNER/$REPO_NAME [run-id]"
echo
echo "🔄 To re-run a failed workflow:"
echo "   gh run rerun --repo $REPO_OWNER/$REPO_NAME [run-id]"
