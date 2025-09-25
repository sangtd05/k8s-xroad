#!/bin/bash

# X-Road Kubernetes Deployment Script
# This script deploys X-Road on a 4-node Kubernetes cluster

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

# Deploy namespace and basic resources
deploy_namespace() {
    print_status "Deploying namespace and basic resources..."
    kubectl apply -f 01-namespace/
    print_success "Namespace and basic resources deployed"
}

# Deploy secrets and configmaps
deploy_configs() {
    print_status "Deploying secrets and configmaps..."
    kubectl apply -f 02-secrets/
    kubectl apply -f 03-configmaps/
    print_success "Secrets and configmaps deployed"
}

# Deploy databases
deploy_databases() {
    print_status "Deploying databases..."
    kubectl apply -f 04-databases/
    print_success "Databases deployed"
    
    # Wait for databases to be ready
    print_status "Waiting for databases to be ready..."
    kubectl wait --for=condition=ready pod -l app=cs-postgres -n xroad --timeout=300s
    kubectl wait --for=condition=ready pod -l app=ss-postgres-primary -n xroad --timeout=300s
    kubectl wait --for=condition=ready pod -l app=ss-postgres-secondary -n xroad --timeout=300s
    print_success "All databases are ready"
}

# Deploy Central Server
deploy_central_server() {
    print_status "Deploying Central Server..."
    kubectl apply -f 05-central-server/
    print_success "Central Server deployed"
    
    # Wait for Central Server to be ready
    print_status "Waiting for Central Server to be ready..."
    kubectl wait --for=condition=ready pod -l app=central-server -n xroad --timeout=600s
    print_success "Central Server is ready"
}

# Deploy Security Servers
deploy_security_servers() {
    print_status "Deploying Security Servers..."
    kubectl apply -f 06-security-server/
    print_success "Security Servers deployed"
    
    # Wait for Security Servers to be ready
    print_status "Waiting for Security Servers to be ready..."
    kubectl wait --for=condition=ready pod -l app=security-server-primary -n xroad --timeout=600s
    kubectl wait --for=condition=ready pod -l app=security-server-secondary -n xroad --timeout=600s
    print_success "All Security Servers are ready"
}

# Deploy networking
deploy_networking() {
    print_status "Deploying networking configuration..."
    kubectl apply -f 07-networking/
    print_success "Networking configuration deployed"
}

# Deploy monitoring
deploy_monitoring() {
    print_status "Deploying monitoring and logging..."
    kubectl apply -f 08-monitoring/
    print_success "Monitoring and logging deployed"
}

# Show deployment status
show_status() {
    print_status "Deployment Status:"
    echo ""
    kubectl get pods -n xroad
    echo ""
    kubectl get services -n xroad
    echo ""
    kubectl get pvc -n xroad
}

# Main deployment function
main() {
    print_status "Starting X-Road Kubernetes deployment..."
    echo ""
    
    check_kubectl
    check_cluster
    
    deploy_namespace
    deploy_configs
    deploy_databases
    deploy_central_server
    deploy_security_servers
    deploy_networking
    deploy_monitoring
    
    print_success "X-Road deployment completed successfully!"
    echo ""
    show_status
    
    print_warning "Next steps:"
    echo "1. Configure SSL certificates in the xroad-tls-secret"
    echo "2. Update DNS records to point to the load balancer IPs"
    echo "3. Initialize X-Road configuration through the admin interfaces"
    echo "4. Set up monitoring dashboards in Grafana"
}

# Handle script arguments
case "${1:-}" in
    "status")
        show_status
        ;;
    "clean")
        print_warning "Cleaning up X-Road deployment..."
        kubectl delete namespace xroad
        print_success "Cleanup completed"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [status|clean|help]"
        echo "  status  - Show deployment status"
        echo "  clean   - Remove all X-Road resources"
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
