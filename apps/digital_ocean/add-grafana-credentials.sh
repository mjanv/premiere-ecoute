#!/bin/bash
# AIDEV-NOTE: Script to add Grafana Cloud credentials for PromEx dashboard upload

set -e

echo "=== Add Grafana Cloud Credentials to Production Environment ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Prompt for credentials
read -p "Enter your Grafana Cloud Host (e.g., https://yourorg.grafana.net): " GRAFANA_HOST
read -p "Enter your Grafana API Token (with Editor/Admin permissions): " GRAFANA_API_TOKEN

# Validate inputs
if [ -z "$GRAFANA_HOST" ] || [ -z "$GRAFANA_API_TOKEN" ]; then
    echo "Error: Both GRAFANA_HOST and GRAFANA_API_TOKEN are required"
    exit 1
fi

echo ""
echo "Adding Grafana credentials to /opt/premiere-ecoute/.env..."

# Add or update credentials in .env file
ENV_FILE="/opt/premiere-ecoute/.env"

# Remove old entries if they exist
sed -i '/^GRAFANA_HOST=/d' "$ENV_FILE"
sed -i '/^GRAFANA_API_TOKEN=/d' "$ENV_FILE"
sed -i '/^GRAFANA_TOKEN=/d' "$ENV_FILE"

# Add new entries
cat >> "$ENV_FILE" << EOF

# Grafana Cloud - Added for PromEx dashboard upload
GRAFANA_HOST=$GRAFANA_HOST
GRAFANA_API_TOKEN=$GRAFANA_API_TOKEN
EOF

echo "Grafana credentials added successfully!"
echo ""
echo "Restarting premiere-ecoute service..."
systemctl restart premiere-ecoute

echo ""
echo "Done! PromEx will now upload dashboards to Grafana Cloud on application start."
echo ""
echo "Check the logs:"
echo "  journalctl -u premiere-ecoute -f | grep -i grafana"
echo ""
