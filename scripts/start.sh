#!/bin/bash

# Script khởi động hệ thống X-Road
# Usage: ./scripts/start.sh [--init] [--ssl]

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
SSL_DIR="nginx/ssl"
CERT_FILE="$SSL_DIR/cert.pem"
KEY_FILE="$SSL_DIR/key.pem"

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

# Hàm kiểm tra prerequisites
check_prerequisites() {
    print_info "Kiểm tra prerequisites..."
    
    # Kiểm tra Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker không được cài đặt hoặc không có trong PATH"
        exit 1
    fi
    
    # Kiểm tra Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose không được cài đặt"
        exit 1
    fi
    
    # Kiểm tra file .env
    if [ ! -f "$ENV_FILE" ]; then
        print_warning "File .env không tồn tại, tạo từ env.example..."
        if [ -f "env.example" ]; then
            cp env.example .env
            print_success "Đã tạo file .env từ env.example"
        else
            print_error "File env.example không tồn tại"
            exit 1
        fi
    fi
    
    print_success "Prerequisites OK"
}

# Hàm tạo SSL certificate
generate_ssl() {
    print_info "Tạo SSL certificate..."
    
    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        print_info "Chứng chỉ SSL không tồn tại, tạo mới..."
        
        # Tạo thư mục SSL
        mkdir -p "$SSL_DIR"
        
        # Tạo private key
        openssl genrsa -out "$KEY_FILE" 2048
        
        # Tạo certificate signing request
        openssl req -new -key "$KEY_FILE" -out "$SSL_DIR/cert.csr" \
            -subj "/C=VN/ST=Hanoi/L=Hanoi/O=X-Road/OU=IT/CN=xroad.localhost"
        
        # Tạo self-signed certificate
        openssl x509 -req -days 365 -in "$SSL_DIR/cert.csr" \
            -signkey "$KEY_FILE" -out "$CERT_FILE"
        
        # Xóa file CSR
        rm "$SSL_DIR/cert.csr"
        
        # Đặt quyền
        chmod 600 "$KEY_FILE"
        chmod 644 "$CERT_FILE"
        
        print_success "SSL certificate đã được tạo"
    else
        print_info "SSL certificate đã tồn tại"
    fi
}

# Hàm khởi động lại hệ thống
restart_system() {
    local init_mode=$1
    local clean_mode=$2
    
    print_info "Bắt đầu khởi động lại hệ thống X-Road..."
    
    # Dừng hệ thống
    print_info "Dừng hệ thống hiện tại..."
    if [ "$clean_mode" = true ]; then
        ./scripts/stop.sh --clean
    else
        ./scripts/stop.sh
    fi
    
    # Chờ một chút
    print_info "Chờ 5 giây..."
    sleep 5
    
    # Khởi động lại hệ thống
    print_info "Khởi động lại hệ thống..."
    if [ "$init_mode" = true ]; then
        ./scripts/start.sh --init
    else
        ./scripts/start.sh
    fi
    
    print_success "Hệ thống X-Road đã được khởi động lại thành công!"
}

# Hàm khởi động services
start_services() {
    print_info "Khởi động các services..."
    
    # Pull images
    print_info "Tải Docker images..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull
    
    # Start services
    print_info "Khởi động containers..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    print_success "Các services đã được khởi động"
}

# Hàm khởi tạo hệ thống
initialize_system() {
    print_info "Khởi tạo hệ thống X-Road..."
    
    # Chờ các services khởi động
    print_info "Chờ các services khởi động hoàn tất..."
    sleep 30
    
    # Kiểm tra health của các services
    print_info "Kiểm tra trạng thái các services..."
    
    # Central Server
    if docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps cs | grep -q "Up"; then
        print_success "Central Server: Running"
    else
        print_error "Central Server: Failed"
    fi
    
    # Security Server
    if docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps ss0 | grep -q "Up"; then
        print_success "Security Server: Running"
    else
        print_error "Security Server: Failed"
    fi
    
    # Test CA
    if docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps testca | grep -q "Up"; then
        print_success "Test CA: Running"
    else
        print_error "Test CA: Failed"
    fi
    
    print_success "Hệ thống X-Road đã được khởi tạo"
}

# Hàm hiển thị thông tin truy cập
show_access_info() {
    print_info "Thông tin truy cập hệ thống:"
    echo ""
    echo "🌐 Web Interfaces:"
    echo "  • Central Server:     https://localhost:4000"
    echo "  • Security Server:    https://localhost:4001"
    echo "  • Test CA:            https://localhost:8888"
    echo "  • Mailpit:            https://localhost:8025"
    echo ""
    echo "🔌 API Endpoints:"
    echo "  • REST API:           http://localhost:8082"
    echo "  • SOAP API:           http://localhost:8083"
    echo "  • OpenAPI:            http://localhost:8084"
    echo ""
    echo "🔐 Default Credentials:"
    echo "  • Username: xrd"
    echo "  • Password: secret"
    echo ""
    echo "📝 Logs:"
    echo "  • View logs:          docker-compose logs -f"
    echo "  • Stop system:        ./scripts/stop.sh"
    echo "  • Restart system:     ./scripts/restart.sh"
    echo ""
    print_warning "Lưu ý: Đây là chứng chỉ SSL tự ký, trình duyệt sẽ cảnh báo bảo mật."
}

# Main function
main() {
    local init_mode=false
    local ssl_mode=false
    local restart_mode=false
    local clean_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --init)
                init_mode=true
                shift
                ;;
            --ssl)
                ssl_mode=true
                shift
                ;;
            --restart)
                restart_mode=true
                shift
                ;;
            --restart-init)
                restart_mode=true
                init_mode=true
                shift
                ;;
            --restart-clean)
                restart_mode=true
                clean_mode=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--init] [--ssl] [--restart] [--restart-init] [--restart-clean]"
                echo "  --init           Khởi tạo hệ thống sau khi khởi động"
                echo "  --ssl            Tạo SSL certificate mới"
                echo "  --restart        Khởi động lại hệ thống"
                echo "  --restart-init   Khởi động lại và khởi tạo"
                echo "  --restart-clean  Khởi động lại với dọn dẹp"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Xử lý restart mode
    if [ "$restart_mode" = true ]; then
        restart_system "$init_mode" "$clean_mode"
        return 0
    fi
    
    print_info "Bắt đầu khởi động hệ thống X-Road..."
    
    # Kiểm tra prerequisites
    check_prerequisites
    
    # Tạo SSL certificate nếu cần
    if [ "$ssl_mode" = true ]; then
        generate_ssl
    fi
    
    # Khởi động services
    start_services
    
    # Khởi tạo hệ thống nếu cần
    if [ "$init_mode" = true ]; then
        initialize_system
    fi
    
    # Hiển thị thông tin truy cập
    show_access_info
    
    print_success "Hệ thống X-Road đã được khởi động thành công!"
}

# Chạy main function
main "$@"
