#!/bin/bash

# X-Road Kubernetes Cleanup Script
# This script removes all X-Road resources from the cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_success "kubectl is available"
}

# Check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"
}

# Cleanup function
cleanup() {
    print_warning "Starting X-Road cleanup..."
    echo ""
    
    check_kubectl
    check_cluster
    
    # Delete all resources in reverse order
    print_status "Deleting monitoring resources..."
    kubectl delete -f 08-monitoring/ --ignore-not-found=true
    
    print_status "Deleting networking resources..."
    kubectl delete -f 07-networking/ --ignore-not-found=true
    
    print_status "Deleting security server resources..."
    kubectl delete -f 06-security-server/ --ignore-not-found=true
    
    print_status "Deleting central server resources..."
    kubectl delete -f 05-central-server/ --ignore-not-found=true
    
    print_status "Deleting database resources..."
    kubectl delete -f 04-databases/ --ignore-not-found=true
    
    print_status "Deleting configuration resources..."
    kubectl delete -f 03-configmaps/ --ignore-not-found=true
    kubectl delete -f 02-secrets/ --ignore-not-found=true
    
    print_status "Deleting namespace..."
    kubectl delete -f 01-namespace/ --ignore-not-found=true
    
    # Wait for namespace to be deleted
    print_status "Waiting for namespace to be deleted..."
    kubectl wait --for=delete namespace/xroad --timeout=300s || true
    
    print_success "X-Road cleanup completed successfully!"
}

# Main cleanup function
main() {
    cleanup
}

# Handle script arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        echo "Usage: $0 [help]"
        echo "  help    - Show this help message"
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
