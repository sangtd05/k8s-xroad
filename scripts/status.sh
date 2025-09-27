#!/bin/bash

# Script kiểm tra trạng thái hệ thống X-Road
# Usage: ./scripts/status.sh

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

# Hàm kiểm tra service
check_service() {
    local service_name=$1
    local display_name=$2
    local port=$3
    
    if docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps "$service_name" | grep -q "Up"; then
        print_success "$display_name: Running (Port: $port)"
        return 0
    else
        print_error "$display_name: Stopped"
        return 1
    fi
}

# Hàm kiểm tra health check
check_health() {
    local service_name=$1
    local display_name=$2
    local url=$3
    
    if curl -s -f -k "$url" > /dev/null 2>&1; then
        print_success "$display_name: Healthy"
        return 0
    else
        print_warning "$display_name: Unhealthy"
        return 1
    fi
}

# Hàm hiển thị thông tin chi tiết
show_detailed_info() {
    print_info "Thông tin chi tiết:"
    echo ""
    
    # Container status
    print_info "Container Status:"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    echo ""
    
    # Resource usage
    print_info "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    echo ""
    
    # Network info
    print_info "Network Information:"
    docker network ls | grep xroad
    echo ""
    
    # Volume info
    print_info "Volume Information:"
    docker volume ls | grep xroad
    echo ""
}

# Hàm hiển thị logs
show_logs() {
    local service_name=$1
    local lines=${2:-50}
    
    if [ -n "$service_name" ]; then
        print_info "Logs for $service_name (last $lines lines):"
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs --tail="$lines" "$service_name"
    else
        print_info "System logs (last $lines lines):"
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs --tail="$lines"
    fi
}

# Main function
main() {
    local show_logs_mode=false
    local service_name=""
    local lines=50
    local detailed_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --logs)
                show_logs_mode=true
                shift
                ;;
            --service)
                service_name="$2"
                shift 2
                ;;
            --lines)
                lines="$2"
                shift 2
                ;;
            --detailed)
                detailed_mode=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--logs] [--service SERVICE] [--lines N] [--detailed]"
                echo "  --logs              Hiển thị logs"
                echo "  --service SERVICE   Chỉ hiển thị logs của service cụ thể"
                echo "  --lines N           Số dòng logs hiển thị (default: 50)"
                echo "  --detailed          Hiển thị thông tin chi tiết"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Kiểm tra file cấu hình
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "File $COMPOSE_FILE không tồn tại"
        exit 1
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        print_error "File $ENV_FILE không tồn tại"
        exit 1
    fi
    
    print_info "Kiểm tra trạng thái hệ thống X-Road..."
    echo ""
    
    # Kiểm tra trạng thái các services
    print_info "Service Status:"
    local all_healthy=true
    
    check_service "cs" "Central Server" "4000" || all_healthy=false
    check_service "ss0" "Security Server" "4001" || all_healthy=false
    check_service "testca" "Test CA" "8888" || all_healthy=false
    check_service "isrest" "REST API" "8080" || all_healthy=false
    check_service "issoap" "SOAP API" "8081" || all_healthy=false
    check_service "isopenapi" "OpenAPI" "8082" || all_healthy=false
    check_service "mailpit" "Mailpit" "8025" || all_healthy=false
    check_service "nginx" "Nginx Proxy" "80/443" || all_healthy=false
    
    echo ""
    
    # Kiểm tra health checks
    print_info "Health Checks:"
    check_health "cs" "Central Server" "https://localhost:4000" || true
    check_health "ss0" "Security Server" "https://localhost:4001" || true
    check_health "testca" "Test CA" "http://localhost:8888/testca/certs" || true
    check_health "isrest" "REST API" "http://localhost:8080/__admin/health" || true
    check_health "issoap" "SOAP API" "http://localhost:8081/example-adapter/Endpoint?wsdl" || true
    check_health "isopenapi" "OpenAPI" "http://localhost:8082/v3/api-docs" || true
    check_health "mailpit" "Mailpit" "http://localhost:8025" || true
    
    echo ""
    
    # Hiển thị thông tin chi tiết nếu cần
    if [ "$detailed_mode" = true ]; then
        show_detailed_info
    fi
    
    # Hiển thị logs nếu cần
    if [ "$show_logs_mode" = true ]; then
        show_logs "$service_name" "$lines"
    fi
    
    # Tổng kết
    if [ "$all_healthy" = true ]; then
        print_success "Tất cả services đang chạy bình thường!"
    else
        print_warning "Một số services có vấn đề. Kiểm tra logs để biết thêm chi tiết."
    fi
}

# Chạy main function
main "$@"
