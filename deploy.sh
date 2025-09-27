#!/bin/bash

# X-Road Helm Deployment Script
# This script deploys a complete X-Road infrastructure on Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="xroad"
RELEASE_NAME="xroad"
VALUES_FILE="xroad-values-example.yaml"
DRY_RUN=false
UPGRADE=false

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
    echo "  -n, --namespace NAME     Kubernetes namespace (default: xroad)"
    echo "  -r, --release NAME       Helm release name (default: xroad)"
    echo "  -f, --values FILE        Values file (default: xroad-values-example.yaml)"
    echo "  -d, --dry-run            Dry run mode"
    echo "  -u, --upgrade            Upgrade existing release"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy with default settings"
    echo "  $0 -n my-xroad -f custom-values.yaml # Deploy with custom namespace and values"
    echo "  $0 -d                                 # Dry run to see what would be deployed"
    echo "  $0 -u                                 # Upgrade existing deployment"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -u|--upgrade)
            UPGRADE=true
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

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    print_error "Values file not found: $VALUES_FILE"
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

# Create namespace if it doesn't exist
print_status "Creating namespace '$NAMESPACE' if it doesn't exist..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
print_success "Namespace '$NAMESPACE' is ready"

# Add Helm repositories
print_status "Adding Helm repositories..."
helm repo add postgres-operator https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add postgres-operator-ui https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm repo update
print_success "Helm repositories added and updated"

# Prepare Helm command
HELM_CMD="helm"
if [ "$DRY_RUN" = true ]; then
    HELM_CMD="$HELM_CMD --dry-run --debug"
    print_warning "Running in dry-run mode"
fi

if [ "$UPGRADE" = true ]; then
    HELM_CMD="$HELM_CMD upgrade --install"
    print_status "Upgrading existing release '$RELEASE_NAME'"
else
    HELM_CMD="$HELM_CMD install"
    print_status "Installing new release '$RELEASE_NAME'"
fi

# Deploy X-Road
print_status "Deploying X-Road with values from '$VALUES_FILE'..."
$HELM_CMD "$RELEASE_NAME" ./helm/xroad \
    --namespace "$NAMESPACE" \
    --values "$VALUES_FILE" \
    --wait \
    --timeout 10m

if [ "$DRY_RUN" = true ]; then
    print_success "Dry run completed successfully"
    exit 0
fi

print_success "X-Road deployment completed successfully"

# Show deployment status
print_status "Deployment status:"
kubectl get pods -n "$NAMESPACE"
echo ""

kubectl get svc -n "$NAMESPACE"
echo ""

# Show access information
print_status "Access Information:"
echo ""

# Central Server access
print_status "Central Server Admin Interface:"
echo "  kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-central-server 4000:4000"
echo "  Then open: https://localhost:4000"
echo "  Default credentials: xrd-sys / secret"
echo ""

# Security Server access
print_status "Security Server Admin Interface:"
echo "  kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-security-server 4000:4000"
echo "  Then open: https://localhost:4000"
echo "  Default credentials: xrd-sys / secret"
echo ""

# Show useful commands
print_status "Useful commands:"
echo "  # Check pod status"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "  # View logs"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=xroad-central-server -f"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=xroad-security-server -f"
echo ""
echo "  # Check services"
echo "  kubectl get svc -n $NAMESPACE"
echo ""
echo "  # Uninstall (if needed)"
echo "  helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""

print_success "X-Road deployment completed successfully!"
print_status "Next steps:"
echo "  1. Access the Central Server admin interface to configure the instance"
echo "  2. Register Security Servers with the Central Server"
echo "  3. Configure Security Server services and clients"
echo "  4. Test the X-Road message exchange"
echo ""
print_status "For more information, see the README.md file"
