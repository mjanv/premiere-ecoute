#!/usr/bin/env bash
# Script to load environment variables from .env.production into GitHub Secrets
# Requires: GitHub CLI (gh) to be installed and authenticated
# Usage: ./load-github-secrets.sh

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Check if .env.production exists
ENV_FILE="../../.env.production"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env.production not found at $ENV_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}=== Loading GitHub Secrets from .env.production ===${NC}\n"

# Variables to exclude from secrets (not needed in GitHub Actions)
EXCLUDED_KEYS=(
    "PORT"
    "PHX_SERVER"
    "ACME_EMAIL"
    "POSTGRES_HOSTNAME"
    "MIX_ENV"
    "GRAFANA_HOST"
    "GRAFANA_TOKEN"
    "DNS_CLUSTER_QUERY"
    "ECTO_IPV6"
    "DATABASE_SSL"
    "TWITCH_WEBHOOK_SECRET"  # Deprecated, using TWITCH_EXTENSION_SECRET
)

# Function to check if a key should be excluded
is_excluded() {
    local key=$1
    for excluded in "${EXCLUDED_KEYS[@]}"; do
        if [ "$key" = "$excluded" ]; then
            return 0
        fi
    done
    return 1
}

echo -e "${BLUE}Parsing .env.production and setting secrets...${NC}\n"

secret_count=0
skipped_count=0

# Read and process each line in the .env.production file
while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    # Extract key and value
    if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"

        # Check if key should be excluded
        if is_excluded "$key"; then
            echo -e "${YELLOW}⊘ Skipping $key (excluded - not needed in GitHub Actions)${NC}"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Skip empty values
        if [ -z "$value" ]; then
            echo -e "${YELLOW}⚠ Skipping $key (empty value)${NC}"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Set the secret using gh CLI
        if echo "$value" | gh secret set "$key" --body - 2>/dev/null; then
            echo -e "${GREEN}✓ Set $key${NC}"
            secret_count=$((secret_count + 1))
        else
            echo -e "${RED}✗ Failed to set $key${NC}"
        fi
    fi
done < "$ENV_FILE"

echo ""
echo -e "${BLUE}Summary: Set $secret_count secrets, skipped $skipped_count${NC}"

echo ""
echo -e "${BLUE}=== SSH Key Setup ===${NC}\n"
echo -e "${YELLOW}Important: You still need to manually set the SSH private key:${NC}"
echo ""
echo "1. If you don't have a deployment SSH key, generate one:"
echo "   ssh-keygen -t ed25519 -C \"github-actions-deploy\" -f ~/.ssh/premiere_ecoute_deploy"
echo ""
echo "2. Add the public key to your droplet:"
echo "   ssh-copy-id -i ~/.ssh/premiere_ecoute_deploy.pub root@68.183.219.251"
echo ""
echo "3. Set the private key as a GitHub Secret:"
echo "   cat ~/.ssh/premiere_ecoute_deploy | gh secret set DO_SSH_PRIVATE_KEY"
echo ""
echo -e "${GREEN}Done! All secrets from .env.production have been loaded.${NC}"
echo -e "${YELLOW}Don't forget to add DO_SSH_PRIVATE_KEY manually!${NC}"
