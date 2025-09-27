#!/bin/bash

# PostgreSQL Cluster Management Script
# This script helps manage PostgreSQL HA cluster for X-Road

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
MANIFEST_FILE="../examples/xroad-postgres-ha.yaml"

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
    echo "PostgreSQL Cluster Management Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create                  Create PostgreSQL HA cluster"
    echo "  delete                  Delete PostgreSQL HA cluster"
    echo "  status                  Check cluster status"
    echo "  logs                    View cluster logs"
    echo "  connect                 Connect to database"
    echo "  backup                  Create database backup"
    echo "  restore                 Restore from backup"
    echo "  scale                   Scale cluster instances"
    echo "  credentials             Show database credentials"
    echo "  help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 create               # Create PostgreSQL cluster"
    echo "  $0 status               # Check cluster status"
    echo "  $0 connect              # Connect to database"
    echo "  $0 scale 5              # Scale to 5 instances"
    echo "  $0 backup               # Create backup"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    if [ ! -f "$MANIFEST_FILE" ]; then
        print_error "PostgreSQL manifest not found: $MANIFEST_FILE"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create PostgreSQL cluster
create_cluster() {
    print_status "Creating PostgreSQL HA cluster..."
    check_prerequisites
    
    # Check if cluster already exists
    if kubectl get postgresql "$CLUSTER_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_warning "PostgreSQL cluster '$CLUSTER_NAME' already exists"
        print_status "Use 'delete' command first if you want to recreate it"
        return 0
    fi
    
    # Apply manifest
    kubectl apply -f "$MANIFEST_FILE"
    print_success "PostgreSQL cluster manifest applied"
    
    # Wait for cluster to be ready
    print_status "Waiting for PostgreSQL cluster to be ready..."
    kubectl wait --for=condition=Ready postgresql/"$CLUSTER_NAME" -n "$NAMESPACE" --timeout=300s || {
        print_warning "PostgreSQL cluster not ready after 5 minutes"
        print_status "Checking cluster status..."
        kubectl get postgresql -n "$NAMESPACE"
        kubectl get pods -n "$NAMESPACE" -l application=spilo
        return 1
    }
    
    print_success "PostgreSQL cluster is ready"
    show_cluster_status
}

# Function to delete PostgreSQL cluster
delete_cluster() {
    print_status "Deleting PostgreSQL HA cluster..."
    check_prerequisites
    
    if ! kubectl get postgresql "$CLUSTER_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_warning "PostgreSQL cluster '$CLUSTER_NAME' not found"
        return 0
    fi
    
    print_warning "This will delete the PostgreSQL cluster and ALL DATA. Continue? (y/N)"
    read -r -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deletion cancelled"
        return 0
    fi
    
    kubectl delete postgresql "$CLUSTER_NAME" -n "$NAMESPACE"
    print_success "PostgreSQL cluster deletion initiated"
    
    # Wait for deletion to complete
    print_status "Waiting for cluster to be deleted..."
    kubectl wait --for=delete postgresql/"$CLUSTER_NAME" -n "$NAMESPACE" --timeout=120s || {
        print_warning "Cluster still exists after 2 minutes"
    }
    
    print_success "PostgreSQL cluster deleted"
}

# Function to show cluster status
show_cluster_status() {
    print_status "PostgreSQL cluster status:"
    echo ""
    
    # Show PostgreSQL resource
    print_status "PostgreSQL resource:"
    kubectl get postgresql -n "$NAMESPACE" || print_warning "No PostgreSQL resources found"
    echo ""
    
    # Show pods
    print_status "PostgreSQL pods:"
    kubectl get pods -n "$NAMESPACE" -l application=spilo -o wide || print_warning "No PostgreSQL pods found"
    echo ""
    
    # Show services
    print_status "PostgreSQL services:"
    kubectl get svc -n "$NAMESPACE" | grep "$CLUSTER_NAME" || print_warning "No PostgreSQL services found"
    echo ""
    
    # Show PVCs
    print_status "PostgreSQL PVCs:"
    kubectl get pvc -n "$NAMESPACE" | grep "$CLUSTER_NAME" || print_warning "No PostgreSQL PVCs found"
    echo ""
    
    # Show cluster details
    print_status "Cluster details:"
    kubectl describe postgresql "$CLUSTER_NAME" -n "$NAMESPACE" || print_warning "Cannot describe cluster"
}

# Function to view cluster logs
view_logs() {
    print_status "Viewing PostgreSQL cluster logs..."
    check_prerequisites
    
    local pods=$(kubectl get pods -n "$NAMESPACE" -l application=spilo --no-headers -o custom-columns=":metadata.name")
    
    if [ -z "$pods" ]; then
        print_warning "No PostgreSQL pods found"
        return 1
    fi
    
    echo "$pods" | while read -r pod; do
        if [ -n "$pod" ]; then
            print_status "Logs for pod: $pod"
            kubectl logs -n "$NAMESPACE" "$pod" --tail=50
            echo "----------------------------------------"
        fi
    done
}

# Function to connect to database
connect_database() {
    print_status "Connecting to PostgreSQL database..."
    check_prerequisites
    
    # Get master pod
    local master_pod=$(kubectl get pods -n "$NAMESPACE" -l application=spilo,spilo-role=master --no-headers -o custom-columns=":metadata.name" | head -1)
    
    if [ -z "$master_pod" ]; then
        print_error "No master pod found"
        return 1
    fi
    
    print_status "Connecting to master pod: $master_pod"
    print_status "Database: xroad, User: xroad"
    echo ""
    
    kubectl exec -it -n "$NAMESPACE" "$master_pod" -- psql -U xroad -d xroad
}

# Function to create backup
create_backup() {
    print_status "Creating PostgreSQL database backup..."
    check_prerequisites
    
    local backup_dir="./backups/postgres/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Get master pod
    local master_pod=$(kubectl get pods -n "$NAMESPACE" -l application=spilo,spilo-role=master --no-headers -o custom-columns=":metadata.name" | head -1)
    
    if [ -z "$master_pod" ]; then
        print_error "No master pod found"
        return 1
    fi
    
    print_status "Creating backup from master pod: $master_pod"
    kubectl exec -n "$NAMESPACE" "$master_pod" -- pg_dump -U xroad -d xroad > "$backup_dir/xroad_backup.sql"
    
    print_success "Backup created: $backup_dir/xroad_backup.sql"
    ls -la "$backup_dir"
}

# Function to restore from backup
restore_backup() {
    local backup_file=${1:-"./backups/postgres/latest/xroad_backup.sql"}
    print_status "Restoring PostgreSQL database from backup: $backup_file"
    check_prerequisites
    
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Get master pod
    local master_pod=$(kubectl get pods -n "$NAMESPACE" -l application=spilo,spilo-role=master --no-headers -o custom-columns=":metadata.name" | head -1)
    
    if [ -z "$master_pod" ]; then
        print_error "No master pod found"
        return 1
    fi
    
    print_warning "This will overwrite current database. Continue? (y/N)"
    read -r -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Restore cancelled"
        return 0
    fi
    
    print_status "Restoring from master pod: $master_pod"
    kubectl exec -i -n "$NAMESPACE" "$master_pod" -- psql -U xroad -d xroad < "$backup_file"
    
    print_success "Database restored successfully"
}

# Function to scale cluster
scale_cluster() {
    local replicas=${1:-3}
    print_status "Scaling PostgreSQL cluster to $replicas instances..."
    check_prerequisites
    
    if ! kubectl get postgresql "$CLUSTER_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_error "PostgreSQL cluster '$CLUSTER_NAME' not found"
        return 1
    fi
    
    kubectl patch postgresql "$CLUSTER_NAME" -n "$NAMESPACE" --type='merge' -p="{\"spec\":{\"numberOfInstances\":$replicas}}"
    
    print_status "Waiting for scaling to complete..."
    kubectl wait --for=condition=Ready postgresql/"$CLUSTER_NAME" -n "$NAMESPACE" --timeout=300s
    
    print_success "Cluster scaled to $replicas instances"
    show_cluster_status
}

# Function to show credentials
show_credentials() {
    print_status "PostgreSQL database credentials:"
    echo ""
    
    # Get credentials from secret
    local secret_name="$CLUSTER_NAME.credentials.$NAMESPACE"
    
    if kubectl get secret "$secret_name" -n "$NAMESPACE" &> /dev/null; then
        print_status "Database credentials:"
        echo "  Master Host (Read/Write): $CLUSTER_NAME.$NAMESPACE.svc.cluster.local"
        echo "  Replica Host (Read Only): $CLUSTER_NAME-repl.$NAMESPACE.svc.cluster.local"
        echo "  Port: 5432"
        echo "  Database: xroad"
        echo "  Username: xroad"
        echo "  Password: $(kubectl get secret "$secret_name" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)"
        echo ""
        
        print_status "Connection strings:"
        echo "  Master (Read/Write): postgresql://xroad:$(kubectl get secret "$secret_name" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)@$CLUSTER_NAME.$NAMESPACE.svc.cluster.local:5432/xroad"
        echo "  Replica (Read Only): postgresql://xroad:$(kubectl get secret "$secret_name" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)@$CLUSTER_NAME-repl.$NAMESPACE.svc.cluster.local:5432/xroad"
    else
        print_warning "Credentials secret not found: $secret_name"
    fi
}

# Main function
main() {
    local command=${1:-"help"}
    
    case $command in
        "create")
            create_cluster
            ;;
        "delete")
            delete_cluster
            ;;
        "status")
            show_cluster_status
            ;;
        "logs")
            view_logs
            ;;
        "connect")
            connect_database
            ;;
        "backup")
            create_backup
            ;;
        "restore")
            shift
            restore_backup "$@"
            ;;
        "scale")
            shift
            scale_cluster "$@"
            ;;
        "credentials")
            show_credentials
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
