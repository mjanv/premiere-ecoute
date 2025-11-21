#!/bin/bash
# AIDEV-NOTE: Install Grafana Alloy on Digital Ocean droplet (systemd, no Docker)

set -e

echo "=== Grafana Alloy Installation Script ==="
echo "This script will install Grafana Alloy as a systemd service"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y curl unzip

# Download and install Alloy
ALLOY_VERSION="1.5.1"
ARCH="amd64"
echo "Installing Grafana Alloy version ${ALLOY_VERSION}..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download Alloy
echo "Downloading Grafana Alloy..."
curl -sLO "https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-${ARCH}.zip"

# Extract and install
echo "Extracting and installing..."
unzip -q "alloy-linux-${ARCH}.zip"
chmod +x "alloy-linux-${ARCH}"
mv "alloy-linux-${ARCH}" /usr/local/bin/alloy

# Cleanup
cd -
rm -rf "$TEMP_DIR"

# Create alloy user (if not exists)
if ! id -u alloy &>/dev/null; then
    echo "Creating alloy user..."
    useradd -r -s /bin/false -d /var/lib/alloy alloy
    echo "User 'alloy' created."
else
    echo "User 'alloy' already exists."
fi

# Create directories
echo "Creating directories..."
mkdir -p /etc/alloy
mkdir -p /var/lib/alloy
chown -R alloy:alloy /var/lib/alloy

# Verify installation
echo ""
echo "Verifying installation..."
alloy --version

echo ""
echo "Grafana Alloy installed successfully!"
echo ""
echo "Next steps:"
echo "1. Configure Alloy by editing /etc/alloy/config.alloy"
echo "2. Set up environment variables in /etc/alloy/env"
echo "3. Install systemd service: cp apps/digital_ocean/systemd/alloy.service /etc/systemd/system/"
echo "4. Enable and start the service:"
echo "   systemctl daemon-reload"
echo "   systemctl enable alloy"
echo "   systemctl start alloy"
echo ""
