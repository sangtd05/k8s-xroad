#!/bin/bash

# X-Road Cleanup Script
# This script removes all X-Road and PostgreSQL Operator installations

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
FORCE=false
KEEP_NAMESPACE=false
KEEP_PVC=false

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAME         X-Road namespace (default: xroad)"
    echo "  -p, --postgres-namespace     PostgreSQL namespace (default: postgres-operator)"
    echo "  -r, --release NAME           Helm release name (default: xroad)"
    echo "  -f, --force                  Force cleanup without confirmation"
    echo "  -k, --keep-namespace         Keep namespaces after cleanup"
    echo "  -v, --keep-pvc               Keep Persistent Volume Claims"
    echo "  -a, --all                    Cleanup everything (X-Road + PostgreSQL Operator)"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Cleanup X-Road only"
    echo "  $0 -a                                 # Cleanup everything"
    echo "  $0 -f -n my-xroad                     # Force cleanup with custom namespace"
    echo "  $0 -k -v                              # Cleanup but keep namespace and PVCs"
}

# Parse command line arguments
CLEANUP_ALL=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -p|--postgres-namespace)
            POSTGRES_NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -k|--keep-namespace)
            KEEP_NAMESPACE=true
            shift
            ;;
        -v|--keep-pvc)
            KEEP_PVC=true
            shift
            ;;
        -a|--all)
            CLEANUP_ALL=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check prerequisites
print_status "Checking prerequisites..."

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

print_success "Prerequisites check passed"

# Check Kubernetes connection
print_status "Checking Kubernetes connection..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Kubernetes connection successful"

# Confirmation prompt
if [ "$FORCE" = false ]; then
    echo ""
    print_warning "This will remove the following components:"
    echo "  - X-Road release: $RELEASE_NAME in namespace: $NAMESPACE"
    if [ "$CLEANUP_ALL" = true ]; then
        echo "  - PostgreSQL Operator in namespace: $POSTGRES_NAMESPACE"
    fi
    if [ "$KEEP_PVC" = false ]; then
        echo "  - All Persistent Volume Claims"
    fi
    if [ "$KEEP_NAMESPACE" = false ]; then
        echo "  - Namespaces: $NAMESPACE"
        if [ "$CLEANUP_ALL" = true ]; then
            echo "  - Namespace: $POSTGRES_NAMESPACE"
        fi
    fi
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
fi

# Function to cleanup X-Road
cleanup_xroad() {
    print_status "Cleaning up X-Road..."
    
    # Check if release exists
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_status "Uninstalling X-Road release: $RELEASE_NAME"
        helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || print_warning "Failed to uninstall X-Road release"
    else
        print_warning "X-Road release '$RELEASE_NAME' not found in namespace '$NAMESPACE'"
    fi
    
    # Delete any remaining resources
    print_status "Deleting remaining X-Road resources..."
    
    # Delete StatefulSets
    kubectl delete statefulset -n "$NAMESPACE" --all --ignore-not-found=true
    
    # Delete Deployments
    kubectl delete deployment -n "$NAMESPACE" --all --ignore-not-found=true
    
    # Delete Services
    kubectl delete service -n "$NAMESPACE" --all --ignore-not-found=true
    
    # Delete ConfigMaps
    kubectl delete configmap -n "$NAMESPACE" --all --ignore-not-found=true
    
    # Delete Secrets
    kubectl delete secret -n "$NAMESPACE" --all --ignore-not-found=true
    
    # Delete PVCs if not keeping them
    if [ "$KEEP_PVC" = false ]; then
        print_status "Deleting Persistent Volume Claims..."
        kubectl delete pvc -n "$NAMESPACE" --all --ignore-not-found=true
    else
        print_warning "Keeping Persistent Volume Claims"
    fi
    
    print_success "X-Road cleanup completed"
}

# Function to cleanup PostgreSQL Operator
cleanup_postgres_operator() {
    print_status "Cleaning up PostgreSQL Operator..."
    
    # Check if postgres-operator release exists
    if helm list -n "$POSTGRES_NAMESPACE" | grep -q "postgres-operator"; then
        print_status "Uninstalling PostgreSQL Operator"
        helm uninstall postgres-operator -n "$POSTGRES_NAMESPACE" || print_warning "Failed to uninstall PostgreSQL Operator"
    else
        print_warning "PostgreSQL Operator not found in namespace '$POSTGRES_NAMESPACE'"
    fi
    
    # Check if postgres-operator-ui release exists
    if helm list -n "$POSTGRES_NAMESPACE" | grep -q "postgres-operator-ui"; then
        print_status "Uninstalling PostgreSQL Operator UI"
        helm uninstall postgres-operator-ui -n "$POSTGRES_NAMESPACE" || print_warning "Failed to uninstall PostgreSQL Operator UI"
    else
        print_warning "PostgreSQL Operator UI not found in namespace '$POSTGRES_NAMESPACE'"
    fi
    
    # Delete any remaining PostgreSQL resources
    print_status "Deleting remaining PostgreSQL resources..."
    
    # Delete PostgreSQL clusters
    kubectl delete postgresql -n "$POSTGRES_NAMESPACE" --all --ignore-not-found=true
    
    # Delete other resources
    kubectl delete all -n "$POSTGRES_NAMESPACE" --all --ignore-not-found=true
    kubectl delete configmap -n "$POSTGRES_NAMESPACE" --all --ignore-not-found=true
    kubectl delete secret -n "$POSTGRES_NAMESPACE" --all --ignore-not-found=true
    
    # Delete PVCs if not keeping them
    if [ "$KEEP_PVC" = false ]; then
        print_status "Deleting PostgreSQL Persistent Volume Claims..."
        kubectl delete pvc -n "$POSTGRES_NAMESPACE" --all --ignore-not-found=true
    else
        print_warning "Keeping PostgreSQL Persistent Volume Claims"
    fi
    
    print_success "PostgreSQL Operator cleanup completed"
}

# Function to cleanup cluster-scoped resources
cleanup_cluster_resources() {
    print_status "Cleaning up cluster-scoped resources..."
    
    # Delete ClusterRoles related to PostgreSQL
    print_status "Deleting PostgreSQL ClusterRoles..."
    kubectl get clusterrole | grep postgres | awk '{print $1}' | while read -r role; do
        if [ -n "$role" ]; then
            print_status "Deleting ClusterRole: $role"
            kubectl delete clusterrole "$role" --ignore-not-found=true
        fi
    done
    
    # Delete ClusterRoleBindings related to PostgreSQL
    print_status "Deleting PostgreSQL ClusterRoleBindings..."
    kubectl get clusterrolebinding | grep postgres | awk '{print $1}' | while read -r binding; do
        if [ -n "$binding" ]; then
            print_status "Deleting ClusterRoleBinding: $binding"
            kubectl delete clusterrolebinding "$binding" --ignore-not-found=true
        fi
    done
    
    # Delete PriorityClasses related to PostgreSQL
    print_status "Deleting PostgreSQL PriorityClasses..."
    kubectl get priorityclass | grep postgres | awk '{print $1}' | while read -r pc; do
        if [ -n "$pc" ]; then
            print_status "Deleting PriorityClass: $pc"
            kubectl delete priorityclass "$pc" --ignore-not-found=true
        fi
    done
    
    # Delete CRDs related to PostgreSQL
    print_status "Deleting PostgreSQL CRDs..."
    kubectl get crd | grep postgres | awk '{print $1}' | while read -r crd; do
        if [ -n "$crd" ]; then
            print_status "Deleting CRD: $crd"
            kubectl delete crd "$crd" --ignore-not-found=true
        fi
    done
    
    print_success "Cluster-scoped resources cleanup completed"
}

# Function to cleanup namespaces
cleanup_namespaces() {
    if [ "$KEEP_NAMESPACE" = false ]; then
        print_status "Cleaning up namespaces..."
        
        # Delete X-Road namespace
        if kubectl get namespace "$NAMESPACE" &> /dev/null; then
            print_status "Deleting namespace: $NAMESPACE"
            kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        else
            print_warning "Namespace '$NAMESPACE' not found"
        fi
        
        # Delete PostgreSQL namespace if cleaning up all
        if [ "$CLEANUP_ALL" = true ]; then
            if kubectl get namespace "$POSTGRES_NAMESPACE" &> /dev/null; then
                print_status "Deleting namespace: $POSTGRES_NAMESPACE"
                kubectl delete namespace "$POSTGRES_NAMESPACE" --ignore-not-found=true
            else
                print_warning "Namespace '$POSTGRES_NAMESPACE' not found"
            fi
        fi
        
        print_success "Namespace cleanup completed"
    else
        print_warning "Keeping namespaces"
    fi
}

# Function to cleanup Persistent Volumes
cleanup_persistent_volumes() {
    if [ "$KEEP_PVC" = false ]; then
        print_status "Cleaning up Persistent Volumes..."
        
        # Get all PVs that are bound to PVCs in our namespaces
        PVS=$(kubectl get pv -o jsonpath='{range .items[?(@.spec.claimRef.namespace=="'$NAMESPACE'")]}{.metadata.name}{"\n"}{end}')
        if [ "$CLEANUP_ALL" = true ]; then
            PVS_POSTGRES=$(kubectl get pv -o jsonpath='{range .items[?(@.spec.claimRef.namespace=="'$POSTGRES_NAMESPACE'")]}{.metadata.name}{"\n"}{end}')
            PVS="$PVS$PVS_POSTGRES"
        fi
        
        if [ -n "$PVS" ]; then
            echo "$PVS" | while read -r pv; do
                if [ -n "$pv" ]; then
                    print_status "Deleting Persistent Volume: $pv"
                    kubectl delete pv "$pv" --ignore-not-found=true
                fi
            done
        fi
        
        print_success "Persistent Volume cleanup completed"
    else
        print_warning "Keeping Persistent Volumes"
    fi
}

# Main cleanup process
print_status "Starting cleanup process..."

# Cleanup X-Road
cleanup_xroad

# Cleanup PostgreSQL Operator if requested
if [ "$CLEANUP_ALL" = true ]; then
    cleanup_postgres_operator
fi

# Cleanup cluster-scoped resources
cleanup_cluster_resources

# Cleanup namespaces
cleanup_namespaces

# Cleanup Persistent Volumes
cleanup_persistent_volumes

# Final verification
print_status "Verifying cleanup..."

# Check remaining resources
REMAINING_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$CLEANUP_ALL" = true ]; then
    REMAINING_PODS_POSTGRES=$(kubectl get pods -n "$POSTGRES_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    REMAINING_PODS=$((REMAINING_PODS + REMAINING_PODS_POSTGRES))
fi

if [ "$REMAINING_PODS" -eq 0 ]; then
    print_success "Cleanup completed successfully! No remaining pods found."
else
    print_warning "Cleanup completed with $REMAINING_PODS remaining pods"
    print_status "Remaining resources:"
    kubectl get all -n "$NAMESPACE" 2>/dev/null || true
    if [ "$CLEANUP_ALL" = true ]; then
        kubectl get all -n "$POSTGRES_NAMESPACE" 2>/dev/null || true
    fi
fi

# Show cleanup summary
echo ""
print_success "Cleanup Summary:"
echo "  ✓ X-Road release '$RELEASE_NAME' removed from namespace '$NAMESPACE'"
if [ "$CLEANUP_ALL" = true ]; then
    echo "  ✓ PostgreSQL Operator removed from namespace '$POSTGRES_NAMESPACE'"
fi
if [ "$KEEP_NAMESPACE" = false ]; then
    echo "  ✓ Namespaces cleaned up"
else
    echo "  ⚠ Namespaces kept"
fi
if [ "$KEEP_PVC" = false ]; then
    echo "  ✓ Persistent Volume Claims and Volumes cleaned up"
else
    echo "  ⚠ Persistent Volume Claims and Volumes kept"
fi

print_success "Cleanup process completed!"
print_status "You can now redeploy X-Road using: ./deploy-3worker.sh"
