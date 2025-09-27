#!/bin/bash

# Quick X-Road Cleanup Script
# This script quickly removes all X-Road installations without confirmation

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

print_status "Starting quick cleanup of X-Road..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed or not in PATH"
    exit 1
fi

# Quick cleanup function
quick_cleanup() {
    local namespace=$1
    local release_name=$2
    
    print_status "Cleaning up namespace: $namespace"
    
    # Uninstall Helm releases
    if helm list -n "$namespace" | grep -q "$release_name"; then
        print_status "Uninstalling Helm release: $release_name"
        helm uninstall "$release_name" -n "$namespace" --ignore-not-found=true
    fi
    
    # Delete all resources in namespace
    print_status "Deleting all resources in namespace: $namespace"
    kubectl delete all --all -n "$namespace" --ignore-not-found=true
    kubectl delete configmap --all -n "$namespace" --ignore-not-found=true
    kubectl delete secret --all -n "$namespace" --ignore-not-found=true
    kubectl delete pvc --all -n "$namespace" --ignore-not-found=true
    
    # Delete namespace
    print_status "Deleting namespace: $namespace"
    kubectl delete namespace "$namespace" --ignore-not-found=true
}

# Cleanup X-Road
print_status "Cleaning up X-Road..."
quick_cleanup "xroad" "xroad"

# Cleanup PostgreSQL Operator
print_status "Cleaning up PostgreSQL Operator..."
quick_cleanup "postgres-operator" "postgres-operator"
quick_cleanup "postgres-operator" "postgres-operator-ui"

# Clean up any orphaned resources
print_status "Cleaning up orphaned resources..."

# Delete any remaining X-Road related resources
kubectl delete postgresql --all --all-namespaces --ignore-not-found=true

# Delete any remaining PVCs that might be orphaned
kubectl get pvc --all-namespaces -o jsonpath='{range .items[?(@.metadata.labels.app\.kubernetes\.io/name=~".*xroad.*")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' | while read -r ns pvc; do
    if [ -n "$ns" ] && [ -n "$pvc" ]; then
        print_status "Deleting orphaned PVC: $pvc in namespace: $ns"
        kubectl delete pvc "$pvc" -n "$ns" --ignore-not-found=true
    fi
done

# Delete any remaining PVs
kubectl get pv -o jsonpath='{range .items[?(@.spec.claimRef.namespace=="xroad")]}{.metadata.name}{"\n"}{end}' | while read -r pv; do
    if [ -n "$pv" ]; then
        print_status "Deleting orphaned PV: $pv"
        kubectl delete pv "$pv" --ignore-not-found=true
    fi
done

kubectl get pv -o jsonpath='{range .items[?(@.spec.claimRef.namespace=="postgres-operator")]}{.metadata.name}{"\n"}{end}' | while read -r pv; do
    if [ -n "$pv" ]; then
        print_status "Deleting orphaned PV: $pv"
        kubectl delete pv "$pv" --ignore-not-found=true
    fi
done

print_success "Quick cleanup completed!"
print_status "All X-Road and PostgreSQL Operator resources have been removed."

# Show remaining resources
print_status "Checking for any remaining resources..."
REMAINING=$(kubectl get all --all-namespaces | grep -i xroad | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    print_warning "Found $REMAINING remaining X-Road related resources:"
    kubectl get all --all-namespaces | grep -i xroad
else
    print_success "No remaining X-Road resources found."
fi

print_status "You can now redeploy X-Road using: ./deploy-3worker.sh"
