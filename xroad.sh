#!/bin/bash

# X-Road Management Script
# Main entry point for all X-Road operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

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
    echo ""
    echo "For more information, see docs/3WORKER_DEPLOYMENT.md"
}

# Function to check if script exists
check_script() {
    local script_name=$1
    local script_path="$SCRIPTS_DIR/$script_name"
    
    if [ ! -f "$script_path" ]; then
        print_error "Script not found: $script_path"
        exit 1
    fi
    
    if [ ! -x "$script_path" ]; then
        print_status "Making script executable: $script_path"
        chmod +x "$script_path"
    fi
}

# Main function
main() {
    local command=${1:-"help"}
    
    case $command in
        "deploy")
            shift
            check_script "deploy-3worker.sh"
            "$SCRIPTS_DIR/deploy-3worker.sh" "$@"
            ;;
        "status")
            check_script "status-check.sh"
            "$SCRIPTS_DIR/status-check.sh"
            ;;
        "logs")
            shift
            check_script "manage.sh"
            "$SCRIPTS_DIR/manage.sh" logs "$@"
            ;;
        "access")
            check_script "manage.sh"
            "$SCRIPTS_DIR/manage.sh" access
            ;;
        "cleanup")
            shift
            check_script "cleanup.sh"
            "$SCRIPTS_DIR/cleanup.sh" "$@"
            ;;
        "quick-cleanup")
            check_script "quick-cleanup.sh"
            "$SCRIPTS_DIR/quick-cleanup.sh"
            ;;
        "restart")
            check_script "manage.sh"
            "$SCRIPTS_DIR/manage.sh" restart
            ;;
        "scale")
            shift
            check_script "manage.sh"
            "$SCRIPTS_DIR/manage.sh" scale "$@"
            ;;
        "backup")
            check_script "manage.sh"
            "$SCRIPTS_DIR/manage.sh" backup
            ;;
        "restore")
            shift
            check_script "manage.sh"
            "$SCRIPTS_DIR/manage.sh" restore "$@"
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
