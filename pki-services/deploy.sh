#!/bin/bash
set -euo pipefail

echo "=== X-Road PKI Services Deployment ==="
echo "This script will deploy CA, OCSP and TSA services"
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

echo "Step 1: Installing dependencies..."
sudo ./scripts/install-dependencies.sh

echo ""
echo "Step 2: Generating PKI..."
sudo ./scripts/generate-pki.sh

echo ""
echo "Step 3: Starting OCSP Responder..."
echo "Starting OCSP in background..."
sudo ./scripts/start-ocsp.sh &
OCSP_PID=$!

# Wait a moment for OCSP to start
sleep 3

echo ""
echo "Step 4: Starting TSA Server..."
echo "Starting TSA in background..."
./scripts/start-tsa.sh &
TSA_PID=$!

# Wait a moment for TSA to start
sleep 3

echo ""
echo "Step 5: Testing services..."

# Test OCSP
echo "Testing OCSP..."
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8888 | grep -q "200\|400"; then
    echo "✓ OCSP Responder is running"
else
    echo "✗ OCSP Responder test failed"
fi

# Test TSA
echo "Testing TSA..."
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/api/v1/timestamp/certchain | grep -q "200"; then
    echo "✓ TSA Server is running"
else
    echo "✗ TSA Server test failed"
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Services running:"
echo "- OCSP Responder: http://$(hostname -I | awk '{print $1}'):8888"
echo "- TSA Server: http://$(hostname -I | awk '{print $1}'):3000/api/v1/timestamp"
echo ""
echo "PKI Files generated:"
echo "- CA Chain: pki/ca-chain.crt"
echo "- OCSP Cert: pki/ocsp.crt"
echo "- TSA Cert: pki/tsa.crt"
echo ""
echo "Next steps:"
echo "1. Configure these services in Central Server:"
echo "   - Import pki/ca-chain.crt as Approved CA"
echo "   - Add OCSP URL: http://$(hostname -I | awk '{print $1}'):8888"
echo "   - Add TSA URL: http://$(hostname -I | awk '{print $1}'):3000/api/v1/timestamp"
echo ""
echo "2. Deploy Security Servers on Kubernetes"
echo ""
echo "To stop services:"
echo "sudo kill $OCSP_PID $TSA_PID"
