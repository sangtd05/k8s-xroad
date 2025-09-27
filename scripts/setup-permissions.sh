#!/bin/bash
# Setup permissions for all scripts
# This script should be run on Linux/Unix systems

echo "Setting up permissions for all scripts..."

# Make all scripts executable
chmod +x scripts/*.sh
chmod +x central-server/deploy.sh
chmod +x central-server/scripts/*.sh
chmod +x pki-services/deploy.sh
chmod +x pki-services/scripts/*.sh
chmod +x security-servers/deploy.sh

echo "Permissions set successfully!"
echo ""
echo "You can now run:"
echo "  ./scripts/deploy-all.sh          # Deploy everything"
echo "  ./scripts/health-check.sh        # Check system health"
echo "  ./central-server/deploy.sh       # Deploy Central Server only"
echo "  ./pki-services/deploy.sh         # Deploy PKI Services only"
echo "  ./security-servers/deploy.sh     # Deploy Security Servers only"
