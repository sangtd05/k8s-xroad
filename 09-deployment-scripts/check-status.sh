#!/bin/bash

# X-Road Kubernetes Status Check Script
# This script checks the status of all X-Road components

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
}

# Check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# Check namespace
check_namespace() {
    print_status "Checking namespace..."
    if kubectl get namespace xroad &> /dev/null; then
        print_success "Namespace 'xroad' exists"
    else
        print_error "Namespace 'xroad' does not exist"
        return 1
    fi
}

# Check pods
check_pods() {
    print_status "Checking pods..."
    echo ""
    kubectl get pods -n xroad
    echo ""
    
    # Check if all pods are running
    local failed_pods=$(kubectl get pods -n xroad --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [ "$failed_pods" -eq 0 ]; then
        print_success "All pods are running"
    else
        print_warning "Some pods are not running. Check the output above."
    fi
}

# Check services
check_services() {
    print_status "Checking services..."
    echo ""
    kubectl get services -n xroad
    echo ""
}

# Check persistent volumes
check_pvc() {
    print_status "Checking persistent volume claims..."
    echo ""
    kubectl get pvc -n xroad
    echo ""
}

# Check ingress
check_ingress() {
    print_status "Checking ingress..."
    echo ""
    kubectl get ingress -n xroad
    echo ""
}

# Check load balancers
check_loadbalancers() {
    print_status "Checking load balancers..."
    echo ""
    kubectl get services -n xroad --field-selector=spec.type=LoadBalancer
    echo ""
}

# Check logs for errors
check_logs() {
    print_status "Checking recent logs for errors..."
    echo ""
    
    local pods=$(kubectl get pods -n xroad --no-headers -o custom-columns=":metadata.name")
    for pod in $pods; do
        echo "=== Logs for $pod ==="
        kubectl logs -n xroad "$pod" --tail=10 2>/dev/null | grep -i error || echo "No errors found"
        echo ""
    done
}

# Main status check function
main() {
    print_status "X-Road Kubernetes Status Check"
    echo ""
    
    check_kubectl
    check_cluster
    
    if check_namespace; then
        check_pods
        check_services
        check_pvc
        check_ingress
        check_loadbalancers
        check_logs
    else
        print_error "Cannot check status - namespace does not exist"
        exit 1
    fi
    
    print_success "Status check completed"
}

# Handle script arguments
case "${1:-}" in
    "pods")
        check_kubectl
        check_cluster
        check_pods
        ;;
    "services")
        check_kubectl
        check_cluster
        check_services
        ;;
    "logs")
        check_kubectl
        check_cluster
        check_logs
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [pods|services|logs|help]"
        echo "  pods     - Check only pod status"
        echo "  services - Check only service status"
        echo "  logs     - Check only logs"
        echo "  help     - Show this help message"
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
