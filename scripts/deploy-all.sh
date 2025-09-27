#!/bin/bash
set -euo pipefail

echo "=== X-Road Complete Deployment ==="
echo "This script will deploy the complete X-Road infrastructure"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as regular user with sudo privileges."
   exit 1
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    print_error "sudo is required but not installed. Please install sudo first."
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_warning "kubectl is not installed. Please install kubectl first."
    print_warning "You can install it from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_status "Starting X-Road deployment..."

# Step 1: Deploy Central Server
print_status "Step 1: Deploying Central Server..."
if [ -d "central-server" ]; then
    cd central-server
    if [ -f "deploy.sh" ]; then
        chmod +x deploy.sh
        ./deploy.sh
        print_status "Central Server deployment completed"
    else
        print_error "deploy.sh not found in central-server directory"
        exit 1
    fi
    cd ..
else
    print_error "central-server directory not found"
    exit 1
fi

# Step 2: Deploy PKI Services
print_status "Step 2: Deploying PKI Services..."
if [ -d "pki-services" ]; then
    cd pki-services
    if [ -f "deploy.sh" ]; then
        chmod +x deploy.sh
        sudo ./deploy.sh
        print_status "PKI Services deployment completed"
    else
        print_error "deploy.sh not found in pki-services directory"
        exit 1
    fi
    cd ..
else
    print_error "pki-services directory not found"
    exit 1
fi

# Step 3: Deploy Security Servers
print_status "Step 3: Deploying Security Servers on Kubernetes..."
if [ -d "security-servers" ]; then
    cd security-servers
    if [ -f "deploy.sh" ]; then
        chmod +x deploy.sh
        ./deploy.sh
        print_status "Security Servers deployment completed"
    else
        print_error "deploy.sh not found in security-servers directory"
        exit 1
    fi
    cd ..
else
    print_error "security-servers directory not found"
    exit 1
fi

# Step 4: Display deployment summary
print_status "=== Deployment Summary ==="
echo ""
print_status "Central Server:"
echo "  - UI: https://$(hostname -f):4000/"
echo "  - Master Security Server: https://127.0.0.1:4001/"
echo ""

print_status "PKI Services:"
echo "  - OCSP: http://$(hostname -I | awk '{print $1}'):8888"
echo "  - TSA: http://$(hostname -I | awk '{print $1}'):3000/api/v1/timestamp"
echo ""

print_status "Security Servers:"
kubectl -n xroad get svc 2>/dev/null || echo "  - Check Kubernetes cluster status"
echo ""

print_status "Next Steps:"
echo "1. Configure PKI Services in Central Server:"
echo "   - Import pki/ca-chain.crt as Approved CA"
echo "   - Add OCSP URL: http://$(hostname -I | awk '{print $1}'):8888"
echo "   - Add TSA URL: http://$(hostname -I | awk '{print $1}'):3000/api/v1/timestamp"
echo ""
echo "2. Register Security Servers:"
echo "   - Download configuration anchor from Central Server"
echo "   - Import anchor into Primary Security Server"
echo "   - Register Security Server with Central Server"
echo ""
echo "3. Test end-to-end communication"
echo ""

print_status "Deployment completed successfully!"
