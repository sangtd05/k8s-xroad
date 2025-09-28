#!/bin/bash

# Script dừng hệ thống X-Road
# Usage: ./scripts/stop.sh [--clean]

set -e

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Biến môi trường
ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"

# Hàm xác định docker compose command
get_docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null; then
        echo "docker compose"
    else
        print_error "Docker Compose không được cài đặt"
        exit 1
    fi
}

# Hàm in thông báo
print_info() {
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

# Hàm dừng services
stop_services() {
    print_info "Dừng các services..."
    
    if [ -f "$COMPOSE_FILE" ]; then
        DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
        $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down
        print_success "Các services đã được dừng"
    else
        print_error "File $COMPOSE_FILE không tồn tại"
        exit 1
    fi
}

# Hàm dọn dẹp (xóa containers, volumes, networks)
clean_system() {
    print_warning "Dọn dẹp hệ thống (xóa containers, volumes, networks)..."
    
    read -p "Bạn có chắc chắn muốn xóa tất cả dữ liệu? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Dừng và xóa containers..."
        DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
        $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down -v --remove-orphans
        
        print_info "Xóa volumes..."
        docker volume prune -f
        
        print_info "Xóa networks không sử dụng..."
        docker network prune -f
        
        print_success "Hệ thống đã được dọn dẹp hoàn toàn"
    else
        print_info "Hủy bỏ dọn dẹp"
    fi
}

# Hàm hiển thị trạng thái
show_status() {
    print_info "Trạng thái hệ thống:"
    echo ""
    
    if [ -f "$COMPOSE_FILE" ]; then
        DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
        $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    else
        print_error "File $COMPOSE_FILE không tồn tại"
    fi
}

# Main function
main() {
    local clean_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                clean_mode=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--clean]"
                echo "  --clean   Dọn dẹp hoàn toàn (xóa containers, volumes, networks)"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    print_info "Bắt đầu dừng hệ thống X-Road..."
    
    # Dừng services
    stop_services
    
    # Dọn dẹp nếu cần
    if [ "$clean_mode" = true ]; then
        clean_system
    fi
    
    # Hiển thị trạng thái
    show_status
    
    print_success "Hệ thống X-Road đã được dừng!"
}

# Chạy main function
main "$@"
