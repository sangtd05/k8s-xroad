#!/bin/bash

# X-Road Status Check Script
# This script checks the status of X-Road deployment and helps with troubleshooting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="xroad"
POSTGRES_NAMESPACE="postgres-operator"
RELEASE_NAME="xroad"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Kubernetes connection
check_k8s_connection() {
    print_status "Checking Kubernetes connection..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    print_success "Kubernetes connection successful"
    return 0
}

# Function to check namespace
check_namespace() {
    local ns=$1
    print_status "Checking namespace: $ns"
    if kubectl get namespace "$ns" &> /dev/null; then
        print_success "Namespace '$ns' exists"
        return 0
    else
        print_error "Namespace '$ns' not found"
        return 1
    fi
}

# Function to check Helm releases
check_helm_releases() {
    local ns=$1
    print_status "Checking Helm releases in namespace: $ns"
    if kubectl get namespace "$ns" &> /dev/null; then
        local releases=$(helm list -n "$ns" --no-headers | wc -l)
        if [ "$releases" -gt 0 ]; then
            print_success "Found $releases Helm release(s) in namespace '$ns':"
            helm list -n "$ns"
        else
            print_warning "No Helm releases found in namespace '$ns'"
        fi
    else
        print_warning "Namespace '$ns' not found, skipping Helm release check"
    fi
}

# Function to check pods
check_pods() {
    local ns=$1
    print_status "Checking pods in namespace: $ns"
    if kubectl get namespace "$ns" &> /dev/null; then
        local total_pods=$(kubectl get pods -n "$ns" --no-headers | wc -l)
        local running_pods=$(kubectl get pods -n "$ns" --no-headers | grep -c "Running" || true)
        local pending_pods=$(kubectl get pods -n "$ns" --no-headers | grep -c "Pending" || true)
        local failed_pods=$(kubectl get pods -n "$ns" --no-headers | grep -c "Failed\|Error\|CrashLoopBackOff" || true)
        
        echo "  Total pods: $total_pods"
        echo "  Running: $running_pods"
        echo "  Pending: $pending_pods"
        echo "  Failed: $failed_pods"
        
        if [ "$failed_pods" -gt 0 ]; then
            print_error "Found $failed_pods failed pods:"
            kubectl get pods -n "$ns" | grep -E "Failed|Error|CrashLoopBackOff"
        fi
        
        if [ "$pending_pods" -gt 0 ]; then
            print_warning "Found $pending_pods pending pods:"
            kubectl get pods -n "$ns" | grep "Pending"
        fi
        
        if [ "$running_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            print_success "All pods are running"
        fi
    else
        print_warning "Namespace '$ns' not found, skipping pod check"
    fi
}

# Function to check services
check_services() {
    local ns=$1
    print_status "Checking services in namespace: $ns"
    if kubectl get namespace "$ns" &> /dev/null; then
        local services=$(kubectl get svc -n "$ns" --no-headers | wc -l)
        if [ "$services" -gt 0 ]; then
            print_success "Found $services service(s) in namespace '$ns':"
            kubectl get svc -n "$ns"
        else
            print_warning "No services found in namespace '$ns'"
        fi
    else
        print_warning "Namespace '$ns' not found, skipping service check"
    fi
}

# Function to check persistent volumes
check_pvc() {
    local ns=$1
    print_status "Checking Persistent Volume Claims in namespace: $ns"
    if kubectl get namespace "$ns" &> /dev/null; then
        local pvcs=$(kubectl get pvc -n "$ns" --no-headers | wc -l)
        if [ "$pvcs" -gt 0 ]; then
            print_success "Found $pvcs PVC(s) in namespace '$ns':"
            kubectl get pvc -n "$ns"
            
            # Check PVC status
            local bound_pvcs=$(kubectl get pvc -n "$ns" --no-headers | grep -c "Bound" || true)
            local pending_pvcs=$(kubectl get pvc -n "$ns" --no-headers | grep -c "Pending" || true)
            
            echo "  Bound: $bound_pvcs"
            echo "  Pending: $pending_pvcs"
            
            if [ "$pending_pvcs" -gt 0 ]; then
                print_warning "Found $pending_pvcs pending PVCs:"
                kubectl get pvc -n "$ns" | grep "Pending"
            fi
        else
            print_warning "No PVCs found in namespace '$ns'"
        fi
    else
        print_warning "Namespace '$ns' not found, skipping PVC check"
    fi
}

# Function to check node resources
check_node_resources() {
    print_status "Checking node resources..."
    if command_exists kubectl; then
        echo "Node information:"
        kubectl get nodes -o wide
        echo ""
        
        # Check if metrics-server is available
        if kubectl top nodes &> /dev/null; then
            print_success "Metrics server available, showing resource usage:"
            kubectl top nodes
        else
            print_warning "Metrics server not available, showing node capacity:"
            kubectl describe nodes | grep -A 5 "Capacity:"
        fi
    else
        print_error "kubectl not available"
    fi
}

# Function to check pod distribution
check_pod_distribution() {
    local ns=$1
    print_status "Checking pod distribution across nodes in namespace: $ns"
    if kubectl get namespace "$ns" &> /dev/null; then
        echo "Pod distribution:"
        kubectl get pods -n "$ns" -o wide --no-headers | awk '{print $7}' | sort | uniq -c | sort -nr
    else
        print_warning "Namespace '$ns' not found, skipping pod distribution check"
    fi
}

# Function to check logs for errors
check_logs() {
    local ns=$1
    print_status "Checking recent logs for errors in namespace: $ns"
    if kubectl get namespace "$ns" &> /dev/null; then
        # Get all pods
        local pods=$(kubectl get pods -n "$ns" --no-headers -o custom-columns=":metadata.name")
        
        if [ -n "$pods" ]; then
            echo "$pods" | while read -r pod; do
                if [ -n "$pod" ]; then
                    print_status "Checking logs for pod: $pod"
                    # Check for error patterns in recent logs
                    local errors=$(kubectl logs -n "$ns" "$pod" --tail=50 2>&1 | grep -i -E "(error|failed|exception|fatal)" | wc -l)
                    if [ "$errors" -gt 0 ]; then
                        print_warning "Found $errors potential errors in pod $pod"
                        kubectl logs -n "$ns" "$pod" --tail=10 | grep -i -E "(error|failed|exception|fatal)" | head -5
                    else
                        print_success "No obvious errors in pod $pod"
                    fi
                fi
            done
        else
            print_warning "No pods found in namespace '$ns'"
        fi
    else
        print_warning "Namespace '$ns' not found, skipping log check"
    fi
}

# Function to show troubleshooting tips
show_troubleshooting_tips() {
    print_status "Troubleshooting Tips:"
    echo ""
    echo "1. If pods are stuck in Pending state:"
    echo "   - Check node resources: kubectl describe nodes"
    echo "   - Check PVC status: kubectl get pvc -n $NAMESPACE"
    echo "   - Check storage class: kubectl get storageclass"
    echo ""
    echo "2. If pods are in CrashLoopBackOff:"
    echo "   - Check pod logs: kubectl logs -n $NAMESPACE <pod-name>"
    echo "   - Check pod description: kubectl describe pod -n $NAMESPACE <pod-name>"
    echo ""
    echo "3. If services are not accessible:"
    echo "   - Check service endpoints: kubectl get endpoints -n $NAMESPACE"
    echo "   - Check service type and ports: kubectl get svc -n $NAMESPACE"
    echo ""
    echo "4. If database connection fails:"
    echo "   - Check PostgreSQL cluster status: kubectl get postgresql -n $POSTGRES_NAMESPACE"
    echo "   - Check database logs: kubectl logs -n $POSTGRES_NAMESPACE -l postgresql.cnpg.io/cluster=xroad-postgresql"
    echo ""
    echo "5. For complete cleanup and redeploy:"
    echo "   - Run: ./cleanup.sh"
    echo "   - Then: ./deploy-3worker.sh"
}

# Main function
main() {
    echo "=========================================="
    echo "X-Road Status Check"
    echo "=========================================="
    echo ""
    
    # Check prerequisites
    if ! command_exists kubectl; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists helm; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check Kubernetes connection
    if ! check_k8s_connection; then
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo "Cluster Information"
    echo "=========================================="
    check_node_resources
    
    echo ""
    echo "=========================================="
    echo "X-Road Namespace ($NAMESPACE)"
    echo "=========================================="
    check_namespace "$NAMESPACE"
    check_helm_releases "$NAMESPACE"
    check_pods "$NAMESPACE"
    check_services "$NAMESPACE"
    check_pvc "$NAMESPACE"
    check_pod_distribution "$NAMESPACE"
    
    echo ""
    echo "=========================================="
    echo "PostgreSQL Operator Namespace ($POSTGRES_NAMESPACE)"
    echo "=========================================="
    check_namespace "$POSTGRES_NAMESPACE"
    check_helm_releases "$POSTGRES_NAMESPACE"
    check_pods "$POSTGRES_NAMESPACE"
    check_services "$POSTGRES_NAMESPACE"
    check_pvc "$POSTGRES_NAMESPACE"
    
    echo ""
    echo "=========================================="
    echo "Log Analysis"
    echo "=========================================="
    check_logs "$NAMESPACE"
    check_logs "$POSTGRES_NAMESPACE"
    
    echo ""
    echo "=========================================="
    echo "Troubleshooting Tips"
    echo "=========================================="
    show_troubleshooting_tips
    
    echo ""
    print_success "Status check completed!"
}

# Run main function
main "$@"
