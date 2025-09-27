#!/bin/bash

# Script cấu hình Security Server từ xa để tham gia mạng X-Road
# Usage: ./scripts/setup-remote-ss.sh [--help]

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

# Hàm hiển thị hướng dẫn
show_instructions() {
    print_info "Hướng dẫn cấu hình Security Server từ xa:"
    echo ""
    echo "1. Cấu hình Central Server để chấp nhận Security Server từ xa:"
    echo "   - Truy cập: https://YOUR_SERVER_IP:4000"
    echo "   - Đăng nhập với tài khoản: xrd / secret"
    echo "   - Vào Management > Security Servers"
    echo "   - Thêm Security Server mới với thông tin:"
    echo "     * Server Code: [Tên server từ xa]"
    echo "     * Address: [IP của server từ xa]"
    echo "     * Port: 4000"
    echo ""
    echo "2. Cấu hình Security Server từ xa:"
    echo "   - Cài đặt X-Road Security Server trên máy từ xa"
    echo "   - Cấu hình kết nối đến Central Server:"
    echo "     * Central Server Address: YOUR_SERVER_IP"
    echo "     * Central Server Port: 4000"
    echo "     * Central Server Protocol: HTTPS"
    echo ""
    echo "3. Cấu hình firewall:"
    echo "   - Mở port 4000 cho Central Server"
    echo "   - Mở port 4000 cho Security Server từ xa"
    echo "   - Mở port 8080/8443 cho proxy services"
    echo ""
    echo "4. Cấu hình DNS (tùy chọn):"
    echo "   - Thêm A record cho centralserver.domain.com -> YOUR_SERVER_IP"
    echo "   - Thêm A record cho securityserver.domain.com -> REMOTE_SERVER_IP"
    echo ""
    echo "5. Kiểm tra kết nối:"
    echo "   - Từ Security Server từ xa, kiểm tra kết nối đến Central Server"
    echo "   - Từ Central Server, kiểm tra Security Server từ xa"
    echo ""
}

# Hàm tạo file cấu hình mẫu
create_config_template() {
    local template_file="remote-ss-config-template.txt"
    
    print_info "Tạo file cấu hình mẫu: $template_file"
    
    cat > "$template_file" << EOF
# Cấu hình Security Server từ xa
# Copy file này đến máy Security Server từ xa và điền thông tin

# =============================================================================
# CENTRAL SERVER CONFIGURATION
# =============================================================================
CENTRAL_SERVER_ADDRESS=YOUR_SERVER_IP
CENTRAL_SERVER_PORT=4000
CENTRAL_SERVER_PROTOCOL=https

# =============================================================================
# SECURITY SERVER CONFIGURATION
# =============================================================================
SECURITY_SERVER_CODE=REMOTE_SS_001
SECURITY_SERVER_ADDRESS=REMOTE_SERVER_IP
SECURITY_SERVER_PORT=4000

# =============================================================================
# X-ROAD INSTANCE CONFIGURATION
# =============================================================================
XROAD_INSTANCE=DEV
MEMBER_CLASS=COM
MEMBER_CODE=1234
SUBSYSTEM_CODE=TestClient

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
DB_HOST=localhost
DB_PORT=5432
DB_NAME=xroad
DB_USER=xroad
DB_PASSWORD=securityserver

# =============================================================================
# SSL CONFIGURATION
# =============================================================================
SSL_CERT_PATH=/etc/xroad/ssl/centralserver.crt
SSL_KEY_PATH=/etc/xroad/ssl/centralserver.key

# =============================================================================
# FIREWALL RULES
# =============================================================================
# Mở các port sau trên Security Server từ xa:
# - 4000: X-Road Admin UI
# - 8080: Proxy HTTP
# - 8443: Proxy HTTPS
# - 5432: PostgreSQL (nếu cần)

# =============================================================================
# CENTRAL SERVER FIREWALL RULES
# =============================================================================
# Mở các port sau trên Central Server:
# - 4000: X-Road Admin UI
# - 8080: Proxy HTTP (nếu cần)
# - 8443: Proxy HTTPS (nếu cần)
EOF

    print_success "File cấu hình mẫu đã được tạo: $template_file"
}

# Hàm tạo script cấu hình tự động
create_setup_script() {
    local script_file="remote-ss-setup.sh"
    
    print_info "Tạo script cấu hình tự động: $script_file"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash

# Script cấu hình Security Server từ xa tự động
# Chạy script này trên máy Security Server từ xa

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Đọc cấu hình
if [ ! -f "remote-ss-config-template.txt" ]; then
    print_error "File cấu hình không tồn tại: remote-ss-config-template.txt"
    exit 1
fi

source remote-ss-config-template.txt

print_info "Bắt đầu cấu hình Security Server từ xa..."

# Kiểm tra prerequisites
print_info "Kiểm tra prerequisites..."
if ! command -v xroad-securityserver &> /dev/null; then
    print_error "X-Road Security Server chưa được cài đặt"
    exit 1
fi

# Cấu hình Central Server connection
print_info "Cấu hình kết nối đến Central Server..."
sudo xroad-confclient --central-server-address "$CENTRAL_SERVER_ADDRESS" \
    --central-server-port "$CENTRAL_SERVER_PORT" \
    --central-server-protocol "$CENTRAL_SERVER_PROTOCOL"

# Cấu hình Security Server
print_info "Cấu hình Security Server..."
sudo xroad-securityserver --server-code "$SECURITY_SERVER_CODE" \
    --server-address "$SECURITY_SERVER_ADDRESS" \
    --server-port "$SECURITY_SERVER_PORT"

# Cấu hình member
print_info "Cấu hình member..."
sudo xroad-member --instance "$XROAD_INSTANCE" \
    --member-class "$MEMBER_CLASS" \
    --member-code "$MEMBER_CODE" \
    --subsystem-code "$SUBSYSTEM_CODE"

# Khởi động services
print_info "Khởi động services..."
sudo systemctl start xroad-proxy
sudo systemctl start xroad-signer
sudo systemctl start xroad-confclient

# Kiểm tra trạng thái
print_info "Kiểm tra trạng thái services..."
sudo systemctl status xroad-proxy
sudo systemctl status xroad-signer
sudo systemctl status xroad-confclient

print_success "Security Server từ xa đã được cấu hình thành công!"
print_info "Truy cập Admin UI tại: https://$SECURITY_SERVER_ADDRESS:4000"
EOF

    chmod +x "$script_file"
    print_success "Script cấu hình tự động đã được tạo: $script_file"
}

# Hàm kiểm tra kết nối
check_connection() {
    local remote_ip=$1
    local remote_port=${2:-4000}
    
    if [ -z "$remote_ip" ]; then
        print_error "Vui lòng cung cấp IP của Security Server từ xa"
        return 1
    fi
    
    print_info "Kiểm tra kết nối đến Security Server từ xa: $remote_ip:$remote_port"
    
    if curl -s -f -k "https://$remote_ip:$remote_port" > /dev/null 2>&1; then
        print_success "Kết nối thành công đến Security Server từ xa"
        return 0
    else
        print_error "Không thể kết nối đến Security Server từ xa"
        return 1
    fi
}

# Hàm hiển thị thông tin mạng
show_network_info() {
    print_info "Thông tin mạng hiện tại:"
    echo ""
    
    # IP addresses
    print_info "IP Addresses:"
    ip addr show | grep "inet " | grep -v "127.0.0.1"
    echo ""
    
    # Open ports
    print_info "Open Ports:"
    netstat -tlnp | grep -E ":(4000|8080|8443|5432)" || true
    echo ""
    
    # Firewall status
    print_info "Firewall Status:"
    if command -v ufw &> /dev/null; then
        sudo ufw status
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --list-all
    else
        print_warning "Không tìm thấy firewall manager"
    fi
    echo ""
}

# Main function
main() {
    local check_mode=false
    local remote_ip=""
    local remote_port=4000
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                check_mode=true
                shift
                ;;
            --remote-ip)
                remote_ip="$2"
                shift 2
                ;;
            --remote-port)
                remote_port="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [--check] [--remote-ip IP] [--remote-port PORT]"
                echo "  --check              Kiểm tra kết nối đến Security Server từ xa"
                echo "  --remote-ip IP       IP của Security Server từ xa"
                echo "  --remote-port PORT   Port của Security Server từ xa (default: 4000)"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    print_info "Cấu hình Security Server từ xa cho X-Road system..."
    echo ""
    
    # Hiển thị hướng dẫn
    show_instructions
    
    # Tạo file cấu hình mẫu
    create_config_template
    
    # Tạo script cấu hình tự động
    create_setup_script
    
    # Hiển thị thông tin mạng
    show_network_info
    
    # Kiểm tra kết nối nếu cần
    if [ "$check_mode" = true ]; then
        check_connection "$remote_ip" "$remote_port"
    fi
    
    print_success "Cấu hình Security Server từ xa hoàn tất!"
    print_info "Các file đã được tạo:"
    echo "  • remote-ss-config-template.txt - File cấu hình mẫu"
    echo "  • remote-ss-setup.sh - Script cấu hình tự động"
    echo ""
    print_info "Bước tiếp theo:"
    echo "  1. Copy các file này đến máy Security Server từ xa"
    echo "  2. Điền thông tin vào remote-ss-config-template.txt"
    echo "  3. Chạy ./remote-ss-setup.sh trên máy từ xa"
    echo "  4. Cấu hình Central Server để chấp nhận Security Server từ xa"
}

# Chạy main function
main "$@"
