#!/bin/bash

# X-Road Security Server SS1 Standalone Deployment Script
# =======================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    log_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        exit 1
    fi
    
    log_success "Docker is running"
}

# Check if Docker Compose is available
check_docker_compose() {
    log_info "Checking Docker Compose..."
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    log_success "Docker Compose is available"
}

# Create environment file if it doesn't exist
setup_environment() {
    if [ ! -f .env ]; then
        log_info "Creating .env file from template..."
        cp env.example .env
        log_warning "Please edit .env file with your configuration before continuing"
        log_info "Current .env file created with default values"
    else
        log_info "Using existing .env file"
    fi
}

# Pull required images
pull_images() {
    log_info "Pulling required Docker images..."
    docker pull ghcr.io/nordic-institute/xrddev-securityserver:latest
    log_success "Images pulled successfully"
}

# Start the SS1 container
start_ss1() {
    log_info "Starting Security Server SS1..."
    
    # Use docker-compose if available, otherwise use docker compose
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    log_success "Security Server SS1 started"
}

# Wait for SS1 to be ready
wait_for_ss1() {
    log_info "Waiting for Security Server SS1 to be ready..."
    
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -k -s https://localhost:4300 > /dev/null 2>&1; then
            log_success "Security Server SS1 is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts - Waiting for SS1 to be ready..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Security Server SS1 failed to start within expected time"
    return 1
}

# Show status and access information
show_status() {
    log_info "Security Server SS1 Status:"
    echo "================================"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose ps
    else
        docker compose ps
    fi
    
    echo ""
    log_info "Access Information:"
    echo "===================="
    echo "Frontend UI: https://localhost:4300"
    echo "Proxy Port:  http://localhost:4310"
    echo "Database:    localhost:4320"
    echo ""
    echo "Debug Ports:"
    echo "  Proxy Debug:      localhost:4390"
    echo "  Signer Debug:     localhost:4391"
    echo "  Proxy UI Debug:   localhost:4392"
    echo "  Conf Client Debug: localhost:4393"
    echo ""
    echo "JMX Ports:"
    echo "  Proxy JMX:        localhost:4399"
    echo "  Signer JMX:       localhost:4398"
    echo ""
    echo "Default Credentials:"
    echo "  Username: xrd"
    echo "  Password: secret"
    echo "  Token PIN: Secret1234"
}

# Stop the SS1 container
stop_ss1() {
    log_info "Stopping Security Server SS1..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose down
    else
        docker compose down
    fi
    
    log_success "Security Server SS1 stopped"
}

# Show logs
show_logs() {
    log_info "Showing Security Server SS1 logs..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose logs -f ss1
    else
        docker compose logs -f ss1
    fi
}

# Main function
main() {
    case "${1:-start}" in
        "start")
            check_docker
            check_docker_compose
            setup_environment
            pull_images
            start_ss1
            wait_for_ss1
            show_status
            ;;
        "stop")
            stop_ss1
            ;;
        "restart")
            stop_ss1
            sleep 5
            start_ss1
            wait_for_ss1
            show_status
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start    Start Security Server SS1 (default)"
            echo "  stop     Stop Security Server SS1"
            echo "  restart  Restart Security Server SS1"
            echo "  status   Show status and access information"
            echo "  logs     Show logs"
            echo "  help     Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
