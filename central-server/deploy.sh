#!/bin/bash
set -euo pipefail

echo "=== X-Road Central Server Deployment ==="
echo "This script will deploy Central Server + Master Security Server"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root. Please run as regular user with sudo privileges."
   exit 1
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    echo "sudo is required but not installed. Please install sudo first."
    exit 1
fi

echo "Step 1: Preparing host system..."
sudo ./scripts/prepare-host.sh

echo ""
echo "Step 2: Installing Central Server..."
sudo ./scripts/install-cs.sh

echo ""
echo "Step 3: Configuring firewall..."
sudo ./scripts/configure-firewall.sh

echo ""
echo "Step 4: Starting Master Security Server..."
sudo ./scripts/start-master-ss.sh

echo ""
echo "Step 5: Running health checks..."
./scripts/health-check.sh

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Central Server UI: https://$(hostname -f):4000/"
echo "Master Security Server UI: https://127.0.0.1:4001/"
echo ""
echo "Credentials:"
if [ -f "compose/.env" ]; then
    echo "Admin User: $(grep XROAD_ADMIN_USER compose/.env | cut -d= -f2)"
    echo "Admin Password: $(grep XROAD_ADMIN_PASSWORD compose/.env | cut -d= -f2)"
    echo "Token PIN: $(grep XROAD_TOKEN_PIN compose/.env | cut -d= -f2)"
fi
echo ""
echo "Next steps:"
echo "1. Install PKI Services"
echo "2. Configure CAs, OCSP, TSA in Central Server"
echo "3. Deploy Security Servers on Kubernetes"
