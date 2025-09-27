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
    echo "  help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy              # Deploy X-Road"
    echo "  $0 status              # Check status"
    echo "  $0 logs central        # View Central Server logs"
    echo "  $0 scale 3             # Scale to 3 secondary nodes"
    echo "  $0 cleanup             # Clean up with confirmation"
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
