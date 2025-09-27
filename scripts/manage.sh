#!/bin/bash

# X-Road Management Script
# This script provides a unified interface for managing X-Road deployment

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

# Function to show usage
show_usage() {
    echo "X-Road Management Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  deploy                 Deploy X-Road on 3-worker cluster"
    echo "  status                 Check deployment status"
    echo "  logs                   View logs"
    echo "  access                 Show access information"
    echo "  cleanup                Clean up deployment (with confirmation)"
    echo "  quick-cleanup          Quick clean up (no confirmation)"
    echo "  restart                Restart X-Road services"
    echo "  scale                  Scale Security Server secondary nodes"
    echo "  backup                 Create backup"
    echo "  restore                Restore from backup"
    echo "  postgres               PostgreSQL management commands"
    echo "  help                   Show this help message"
    echo ""
    echo "Cleanup Options:"
    echo "  -n, --namespace NAME     Kubernetes namespace (default: xroad)"
    echo "  -r, --release NAME       Helm release name (default: xroad)"
    echo "  -f, --force              Force cleanup without confirmation"
    echo "  -k, --keep-namespace     Keep namespace after cleanup"
    echo "  -v, --keep-pvc           Keep Persistent Volume Claims"
    echo "  -a, --all                Cleanup everything (X-Road + PostgreSQL Operator)"
    echo ""
    echo "Examples:"
    echo "  $0 deploy              # Deploy X-Road"
    echo "  $0 status              # Check status"
    echo "  $0 logs central        # View Central Server logs"
    echo "  $0 scale 3             # Scale to 3 secondary nodes"
    echo "  $0 cleanup             # Clean up with confirmation"
    echo "  $0 cleanup -f -a       # Force cleanup everything"
    echo "  $0 quick-cleanup       # Quick clean up"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to deploy X-Road
deploy_xroad() {
    print_status "Deploying X-Road on 3-worker cluster..."
    check_prerequisites
    
    if [ -f "./deploy-3worker.sh" ]; then
        chmod +x ./deploy-3worker.sh
        ./deploy-3worker.sh "$@"
    else
        print_error "deploy-3worker.sh not found"
        exit 1
    fi
}

# Function to check status
check_status() {
    print_status "Checking X-Road deployment status..."
    check_prerequisites
    
    if [ -f "./status-check.sh" ]; then
        chmod +x ./status-check.sh
        ./status-check.sh
    else
        print_error "status-check.sh not found"
        exit 1
    fi
}

# Function to view logs
view_logs() {
    local component=${1:-"all"}
    print_status "Viewing logs for: $component"
    check_prerequisites
    
    case $component in
        "central")
            print_status "Central Server logs:"
            kubectl logs -n xroad -l app.kubernetes.io/name=xroad-central-server -f
            ;;
        "security")
            print_status "Security Server logs:"
            kubectl logs -n xroad -l app.kubernetes.io/name=xroad-security-server -f
            ;;
        "postgres")
            print_status "PostgreSQL logs:"
            kubectl logs -n postgres-operator -l postgresql.cnpg.io/cluster=xroad-postgresql -f
            ;;
        "all")
            print_status "All X-Road logs:"
            kubectl logs -n xroad -l app.kubernetes.io/name=xroad-central-server -f &
            kubectl logs -n xroad -l app.kubernetes.io/name=xroad-security-server -f &
            wait
            ;;
        *)
            print_error "Unknown component: $component"
            echo "Available components: central, security, postgres, all"
            exit 1
            ;;
    esac
}

# Function to show access information
show_access() {
    print_status "X-Road Access Information"
    echo ""
    echo "Central Server Admin Interface:"
    echo "  kubectl port-forward -n xroad svc/xroad-central-server 4000:4000"
    echo "  Then open: https://localhost:4000"
    echo "  Default credentials: xrd-sys / secret"
    echo ""
    echo "Security Server Admin Interface:"
    echo "  kubectl port-forward -n xroad svc/xroad-security-server 4000:4000"
    echo "  Then open: https://localhost:4000"
    echo "  Default credentials: xrd-sys / secret"
    echo ""
    echo "PostgreSQL Operator UI:"
    echo "  kubectl port-forward -n postgres-operator svc/postgres-operator-ui 8081:80"
    echo "  Then open: http://localhost:8081"
    echo ""
    echo "NodePort Access (if using NodePort):"
    echo "  Central Server: https://<node-ip>:30060"
    echo "  Security Server: https://<node-ip>:30050"
    echo ""
    echo "Get node IPs:"
    kubectl get nodes -o wide
}

# Function to cleanup
cleanup_xroad() {
    print_status "Cleaning up X-Road deployment..."
    check_prerequisites
    
    if [ -f "./cleanup.sh" ]; then
        chmod +x ./cleanup.sh
        ./cleanup.sh "$@"
    else
        print_error "cleanup.sh not found"
        exit 1
    fi
}

# Function to quick cleanup
quick_cleanup() {
    print_status "Quick cleaning up X-Road deployment..."
    check_prerequisites
    
    if [ -f "./quick-cleanup.sh" ]; then
        chmod +x ./quick-cleanup.sh
        ./quick-cleanup.sh
    else
        print_error "quick-cleanup.sh not found"
        exit 1
    fi
}

# Function to restart services
restart_services() {
    print_status "Restarting X-Road services..."
    check_prerequisites
    
    print_status "Restarting Central Server..."
    kubectl rollout restart statefulset xroad-central-server -n xroad
    
    print_status "Restarting Security Server Primary..."
    kubectl rollout restart statefulset xroad-security-server-primary -n xroad
    
    print_status "Restarting Security Server Secondary..."
    kubectl rollout restart deployment xroad-security-server-secondary -n xroad
    
    print_status "Waiting for services to be ready..."
    kubectl rollout status statefulset xroad-central-server -n xroad
    kubectl rollout status statefulset xroad-security-server-primary -n xroad
    kubectl rollout status deployment xroad-security-server-secondary -n xroad
    
    print_success "Services restarted successfully"
}

# Function to scale Security Server
scale_security_server() {
    local replicas=${1:-2}
    print_status "Scaling Security Server secondary nodes to: $replicas"
    check_prerequisites
    
    kubectl scale deployment xroad-security-server-secondary -n xroad --replicas="$replicas"
    
    print_status "Waiting for scaling to complete..."
    kubectl rollout status deployment xroad-security-server-secondary -n xroad
    
    print_success "Scaling completed. Current replica count:"
    kubectl get deployment xroad-security-server-secondary -n xroad
}

# Function to create backup
create_backup() {
    print_status "Creating X-Road backup..."
    check_prerequisites
    
    local backup_dir="./backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    print_status "Backing up Central Server configuration..."
    kubectl exec -n xroad xroad-central-server-0 -- tar czf - /etc/xroad > "$backup_dir/central-config.tar.gz" || true
    
    print_status "Backing up Security Server configuration..."
    kubectl exec -n xroad xroad-security-server-primary-0 -- tar czf - /etc/xroad > "$backup_dir/security-config.tar.gz" || true
    
    print_status "Backing up database..."
    kubectl exec -n postgres-operator xroad-postgresql-1 -- pg_dump -U xroad xroad > "$backup_dir/database.sql" || true
    
    print_success "Backup created in: $backup_dir"
    ls -la "$backup_dir"
}

# Function to restore from backup
restore_backup() {
    local backup_dir=${1:-"./backups/latest"}
    print_status "Restoring X-Road from backup: $backup_dir"
    check_prerequisites
    
    if [ ! -d "$backup_dir" ]; then
        print_error "Backup directory not found: $backup_dir"
        exit 1
    fi
    
    print_warning "This will overwrite current configuration. Continue? (y/N)"
    read -r -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Restore cancelled"
        exit 0
    fi
    
    if [ -f "$backup_dir/central-config.tar.gz" ]; then
        print_status "Restoring Central Server configuration..."
        kubectl exec -i -n xroad xroad-central-server-0 -- tar xzf - -C / < "$backup_dir/central-config.tar.gz" || true
    fi
    
    if [ -f "$backup_dir/security-config.tar.gz" ]; then
        print_status "Restoring Security Server configuration..."
        kubectl exec -i -n xroad xroad-security-server-primary-0 -- tar xzf - -C / < "$backup_dir/security-config.tar.gz" || true
    fi
    
    if [ -f "$backup_dir/database.sql" ]; then
        print_status "Restoring database..."
        kubectl exec -i -n postgres-operator xroad-postgresql-1 -- psql -U xroad xroad < "$backup_dir/database.sql" || true
    fi
    
    print_success "Restore completed. Restarting services..."
    restart_services
}

# Function to cleanup X-Road deployment
cleanup_xroad() {
    local namespace="xroad"
    local release_name="xroad"
    local postgres_namespace="postgres-operator"
    local force=false
    local keep_namespace=false
    local keep_pvc=false
    local cleanup_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                namespace="$2"
                shift 2
                ;;
            -r|--release)
                release_name="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -k|--keep-namespace)
                keep_namespace=true
                shift
                ;;
            -v|--keep-pvc)
                keep_pvc=true
                shift
                ;;
            -a|--all)
                cleanup_all=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    print_status "Cleaning up X-Road deployment..."
    check_prerequisites
    
    # Confirmation prompt
    if [ "$force" = false ]; then
        echo ""
        print_warning "This will remove the following components:"
        echo "  - X-Road release: $release_name in namespace: $namespace"
        if [ "$cleanup_all" = true ]; then
            echo "  - PostgreSQL Operator in namespace: $postgres_namespace"
        fi
        if [ "$keep_pvc" = false ]; then
            echo "  - All Persistent Volume Claims"
        fi
        if [ "$keep_namespace" = false ]; then
            echo "  - Namespaces: $namespace"
            if [ "$cleanup_all" = true ]; then
                echo "  - Namespace: $postgres_namespace"
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
    
    # Uninstall X-Road
    print_status "Uninstalling X-Road release: $release_name"
    if helm list -n "$namespace" | grep -q "$release_name"; then
        helm uninstall "$release_name" -n "$namespace" || print_warning "Failed to uninstall X-Road release"
    else
        print_warning "X-Road release '$release_name' not found in namespace '$namespace'"
    fi
    
    # Uninstall PostgreSQL Operator if requested
    if [ "$cleanup_all" = true ]; then
        print_status "Uninstalling PostgreSQL Operator..."
        if helm list -n "$postgres_namespace" | grep -q "postgres-operator"; then
            helm uninstall postgres-operator -n "$postgres_namespace" || print_warning "Failed to uninstall PostgreSQL Operator"
        fi
        if helm list -n "$postgres_namespace" | grep -q "postgres-operator-ui"; then
            helm uninstall postgres-operator-ui -n "$postgres_namespace" || print_warning "Failed to uninstall PostgreSQL Operator UI"
        fi
    fi
    
    # Remove PVCs if not keeping them
    if [ "$keep_pvc" = false ]; then
        print_status "Removing Persistent Volume Claims..."
        kubectl delete pvc --all -n "$namespace" || print_warning "Failed to remove PVCs"
        if [ "$cleanup_all" = true ]; then
            kubectl delete pvc --all -n "$postgres_namespace" || print_warning "Failed to remove PostgreSQL PVCs"
        fi
    fi
    
    # Remove namespaces if not keeping them
    if [ "$keep_namespace" = false ]; then
        print_status "Removing namespaces..."
        kubectl delete namespace "$namespace" || print_warning "Failed to remove namespace '$namespace'"
        if [ "$cleanup_all" = true ]; then
            kubectl delete namespace "$postgres_namespace" || print_warning "Failed to remove namespace '$postgres_namespace'"
        fi
    fi
    
    print_success "Cleanup completed"
}

# Function to quick cleanup (no confirmation)
quick_cleanup() {
    print_status "Quick cleaning up X-Road deployment..."
    cleanup_xroad -f
}

# PostgreSQL Management Functions
# Function to create PostgreSQL cluster
create_postgres_cluster() {
    local manifest_file="../examples/xroad-postgres-ha.yaml"
    local cluster_name="xroad-postgres-ha"
    local namespace="xroad"
    
    print_status "Creating PostgreSQL HA cluster..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    if [ ! -f "$manifest_file" ]; then
        print_error "PostgreSQL manifest not found: $manifest_file"
        exit 1
    fi
    
    # Check if cluster already exists
    if kubectl get postgresql "$cluster_name" -n "$namespace" &> /dev/null; then
        print_warning "PostgreSQL cluster '$cluster_name' already exists"
        print_status "Use 'delete' command first if you want to recreate it"
        return 0
    fi
    
    # Apply manifest
    kubectl apply -f "$manifest_file"
    print_success "PostgreSQL cluster manifest applied"
    
    # Wait for cluster to be ready
    print_status "Waiting for PostgreSQL cluster to be ready..."
    kubectl wait --for=condition=Ready postgresql/"$cluster_name" -n "$namespace" --timeout=300s || {
        print_warning "PostgreSQL cluster not ready after 5 minutes"
        print_status "Checking cluster status..."
        kubectl get postgresql -n "$namespace"
        kubectl get pods -n "$namespace" -l application=spilo
        return 1
    }
    
    print_success "PostgreSQL cluster is ready"
    show_postgres_status
}

# Function to show PostgreSQL cluster status
show_postgres_status() {
    local cluster_name="xroad-postgres-ha"
    local namespace="xroad"
    
    print_status "PostgreSQL cluster status:"
    echo ""
    
    # Show PostgreSQL resource
    kubectl get postgresql "$cluster_name" -n "$namespace" -o wide
    echo ""
    
    # Show pods
    print_status "PostgreSQL pods:"
    kubectl get pods -n "$namespace" -l application=spilo -o wide
    echo ""
    
    # Show services
    print_status "PostgreSQL services:"
    kubectl get svc -n "$namespace" | grep "$cluster_name"
    echo ""
    
    # Show PVCs
    print_status "PostgreSQL PVCs:"
    kubectl get pvc -n "$namespace" | grep "$cluster_name"
    echo ""
}

# Function to connect to PostgreSQL
connect_postgres() {
    local cluster_name="xroad-postgres-ha"
    local namespace="xroad"
    local database="xroad"
    local username="xroad"
    
    print_status "Connecting to PostgreSQL database..."
    
    # Get password from secret
    local password
    password=$(kubectl get secret "$cluster_name.credentials.$username" -n "$namespace" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)
    
    if [ -z "$password" ]; then
        print_warning "Could not retrieve password from secret, trying alternative names..."
        password=$(kubectl get secret "$cluster_name.$username.credentials" -n "$namespace" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)
    fi
    
    if [ -z "$password" ]; then
        print_warning "Could not retrieve password from secret, using default"
        password="xroad123"
    fi
    
    # Get master pod name
    local master_pod
    master_pod=$(kubectl get pods -n "$namespace" -l application=spilo,spilo-role=master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$master_pod" ]; then
        print_error "Could not find master pod"
        return 1
    fi
    
    print_status "Connecting to master pod: $master_pod"
    print_status "Database: $database, User: $username"
    echo ""
    
    # Connect to database
    kubectl exec -it "$master_pod" -n "$namespace" -- psql -U "$username" -d "$database"
}

# Function to create PostgreSQL PersistentVolumes
create_postgres_pvs() {
    local cluster_name="xroad-postgres-ha"
    local storage_class="xroad-storage"
    local pv_size="10Gi"
    
    print_status "Creating PersistentVolumes for PostgreSQL HA cluster..."
    
    # Get worker nodes
    local worker_nodes
    worker_nodes=$(kubectl get nodes -l node-role.kubernetes.io/worker= -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$worker_nodes" ]; then
        print_error "No worker nodes found"
        return 1
    fi
    
    print_status "Found worker nodes: $worker_nodes"
    
    # Create PVs for each instance
    local instance=0
    for node in $worker_nodes; do
        local pv_name="pv-${cluster_name}-${instance}"
        local pv_path="/mnt/disks/postgres-ha-${instance}"
        
        print_status "Creating PV '$pv_name' on node '$node' with path '$pv_path'..."
        
        # Create local directory on the node
        kubectl debug node/"$node" -it --image=ubuntu -- bash -c "mkdir -p $pv_path && chmod 777 $pv_path" || {
            print_warning "Could not create local path $pv_path on node $node. Ensure SSH access or manual creation."
        }
        
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $pv_name
  labels:
    cluster: $cluster_name
spec:
  capacity:
    storage: $pv_size
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: $storage_class
  local:
    path: $pv_path
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
            - $node
EOF
        print_success "PV '$pv_name' created."
        ((instance++))
    done
    
    print_success "All PersistentVolumes created"
    print_status "Created PVs:"
    kubectl get pv | grep "$cluster_name"
}

# Main function
main() {
    local command=${1:-"help"}
    
    case $command in
        "deploy")
            shift
            deploy_xroad "$@"
            ;;
        "status")
            check_status
            ;;
        "logs")
            shift
            view_logs "$@"
            ;;
        "access")
            show_access
            ;;
        "cleanup")
            shift
            cleanup_xroad "$@"
            ;;
        "quick-cleanup")
            quick_cleanup
            ;;
        "restart")
            restart_services
            ;;
        "scale")
            shift
            scale_security_server "$@"
            ;;
        "backup")
            create_backup
            ;;
        "restore")
            shift
            restore_backup "$@"
            ;;
        "postgres")
            shift
            case ${1:-"help"} in
                "create")
                    create_postgres_cluster
                    ;;
                "status")
                    show_postgres_status
                    ;;
                "connect")
                    connect_postgres
                    ;;
                "create-pvs")
                    create_postgres_pvs
                    ;;
                "help"|"--help"|"-h")
                    echo "PostgreSQL Management Commands:"
                    echo "  create                  Create PostgreSQL HA cluster"
                    echo "  status                  Show cluster status"
                    echo "  connect                 Connect to database"
                    echo "  create-pvs              Create PersistentVolumes"
                    echo ""
                    ;;
                *)
                    print_error "Unknown PostgreSQL command: $1"
                    echo "Use 'postgres help' for available commands"
                    exit 1
                    ;;
            esac
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
