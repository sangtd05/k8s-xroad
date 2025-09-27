#!/bin/bash

# Test PostgreSQL Secret Name Script
# This script helps verify the correct PostgreSQL secret name

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="xroad"
CLUSTER_NAME="xroad-postgres-ha"

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

# Function to test secret names
test_secret_names() {
    print_status "Testing PostgreSQL secret names..."
    echo ""
    
    # Test different possible secret names
    local secret_names=(
        "xroad-postgres-ha.credentials.xroad"
        "xroad-postgres-ha.xroad.credentials"
        "xroad-postgres-ha-credentials"
        "xroad-postgres-ha-credentials.xroad"
    )
    
    local found_secret=""
    
    for secret_name in "${secret_names[@]}"; do
        print_status "Testing secret: $secret_name"
        if kubectl get secret "$secret_name" -n "$NAMESPACE" &> /dev/null; then
            print_success "Found secret: $secret_name"
            found_secret="$secret_name"
            
            # Show secret details
            print_status "Secret details:"
            kubectl get secret "$secret_name" -n "$NAMESPACE" -o yaml | grep -A 5 "data:"
            
            # Test password extraction
            local password=$(kubectl get secret "$secret_name" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "")
            if [ -n "$password" ]; then
                print_success "Password extracted successfully: ${password:0:4}****"
            else
                print_warning "Could not extract password from secret"
            fi
            
            break
        else
            print_warning "Secret not found: $secret_name"
        fi
        echo ""
    done
    
    if [ -z "$found_secret" ]; then
        print_error "No PostgreSQL secret found with any of the tested names"
        print_status "Available secrets in namespace $NAMESPACE:"
        kubectl get secrets -n "$NAMESPACE" | grep postgres || print_warning "No postgres-related secrets found"
    else
        print_success "Correct secret name: $found_secret"
    fi
}

# Function to show all secrets
show_all_secrets() {
    print_status "All secrets in namespace $NAMESPACE:"
    kubectl get secrets -n "$NAMESPACE" || print_warning "No secrets found"
    echo ""
    
    print_status "PostgreSQL-related secrets:"
    kubectl get secrets -n "$NAMESPACE" | grep -i postgres || print_warning "No postgres-related secrets found"
}

# Function to show PostgreSQL cluster status
show_cluster_status() {
    print_status "PostgreSQL cluster status:"
    kubectl get postgresql -n "$NAMESPACE" || print_warning "No PostgreSQL cluster found"
    echo ""
    
    print_status "PostgreSQL pods:"
    kubectl get pods -n "$NAMESPACE" -l application=spilo || print_warning "No PostgreSQL pods found"
}

# Main function
main() {
    echo "=========================================="
    echo "PostgreSQL Secret Name Test"
    echo "=========================================="
    echo ""
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check Kubernetes connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_error "Namespace '$NAMESPACE' not found"
        exit 1
    fi
    
    show_cluster_status
    echo ""
    show_all_secrets
    echo ""
    test_secret_names
}

# Run main function
main "$@"
