#!/bin/bash

# GitHub Repository Creation and Push Script
# This script will create a GitHub repository and push all files

set -e

echo "🚀 Creating GitHub repository and pushing files..."
echo ""

# Check if authenticated
echo "📋 Checking GitHub CLI authentication..."
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Not authenticated with GitHub. Please run:"
    echo "   gh auth login"
    echo ""
    echo "Follow the prompts to authenticate via web browser."
    exit 1
fi

echo "✅ GitHub CLI authenticated successfully"
echo ""

# Create the repository
echo "📦 Creating GitHub repository..."
REPO_NAME="confluent-cluster-linking-demo"
REPO_DESC="Automated setup for Confluent Platform clusters with bidirectional linking and auto-mirroring"

gh repo create "$REPO_NAME" \
    --public \
    --description "$REPO_DESC" \
    --source=. \
    --remote=origin \
    --push

echo ""
echo "🎉 Success! Repository created and files pushed."
echo ""
echo "📋 Repository Details:"
echo "   Name: $REPO_NAME"
echo "   URL: https://github.com/$(gh api user --jq '.login')/$REPO_NAME"
echo "   Visibility: Public"
echo ""
echo "✅ All files have been uploaded to GitHub!"
echo ""
echo "🔗 You can view your repository at:"
gh repo view --web

echo ""
echo "📁 Files uploaded:"
git ls-files | sed 's/^/   - /'
