#!/bin/bash
# AIDEV-NOTE: Native server setup script for Digital Ocean droplet (one-time setup)

set -e

echo "=== Native Server Setup Script ==="
echo "This script will install PostgreSQL, Traefik, and dependencies"
echo ""

# Update system packages
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    curl \
    wget \
    gnupg \
    ca-certificates \
    locales \
    unzip

# Setup locale
echo "Setting up locale..."
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Install PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "Installing PostgreSQL..."
    apt-get install -y postgresql postgresql-contrib
    systemctl start postgresql
    systemctl enable postgresql
    echo "PostgreSQL installed successfully!"
else
    echo "PostgreSQL is already installed."
fi

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';" || true
sudo -u postgres psql -c "CREATE DATABASE premiere_ecoute_prod;" || echo "Database already exists"

# Create application user
if ! id -u premiere &>/dev/null; then
    echo "Creating application user..."
    useradd -r -s /bin/bash -d /home/premiere -m premiere
    echo "User 'premiere' created."
else
    echo "User 'premiere' already exists."
fi

# Create traefik user
if ! id -u traefik &>/dev/null; then
    echo "Creating traefik user..."
    useradd -r -s /bin/false -d /opt/traefik traefik
    echo "User 'traefik' created."
else
    echo "User 'traefik' already exists."
fi

# Install Traefik
if ! command -v traefik &> /dev/null; then
    echo "Installing Traefik..."
    TRAEFIK_VERSION="v3.3.0"
    wget -q "https://github.com/traefik/traefik/releases/download/${TRAEFIK_VERSION}/traefik_${TRAEFIK_VERSION}_linux_amd64.tar.gz"
    tar -xzf "traefik_${TRAEFIK_VERSION}_linux_amd64.tar.gz"
    mv traefik /usr/local/bin/
    chmod +x /usr/local/bin/traefik
    rm "traefik_${TRAEFIK_VERSION}_linux_amd64.tar.gz"

    # Create Traefik directories
    mkdir -p /opt/traefik
    chown -R traefik:traefik /opt/traefik

    # Allow traefik to bind to privileged ports
    setcap 'cap_net_bind_service=+ep' /usr/local/bin/traefik

    echo "Traefik installed successfully!"
else
    echo "Traefik is already installed."
fi

# Verify Traefik installation
echo "Traefik version:"
traefik version

# Setup firewall (UFW)
echo "Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw --force enable
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8080/tcp  # Traefik dashboard
    ufw status
fi

# Create deployment directory
echo "Creating deployment directory..."
mkdir -p /opt/premiere-ecoute
chown premiere:premiere /opt/premiere-ecoute

echo ""
echo "Native server setup completed successfully!"
echo ""
echo "PostgreSQL Status:"
systemctl status postgresql --no-pager -l || true
echo ""
echo "Next steps:"
echo "1. Deploy the application using ./deploy.sh"
