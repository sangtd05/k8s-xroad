#!/bin/bash

# Script backup hệ thống X-Road
# Usage: ./scripts/backup.sh [--restore BACKUP_FILE]

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
BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

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

# Hàm tạo backup
create_backup() {
    local backup_name="xroad-backup-$TIMESTAMP"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_info "Tạo backup: $backup_name"
    
    # Tạo thư mục backup
    mkdir -p "$backup_path"
    
    # Backup databases
    print_info "Backup databases..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T centralserver \
        pg_dump -U xroad xroad > "$backup_path/centralserver.sql"
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T securityserver1 \
        pg_dump -U xroad xroad > "$backup_path/securityserver1.sql"
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T securityserver2 \
        pg_dump -U xroad xroad > "$backup_path/securityserver2.sql"
    
    # Backup configurations
    print_info "Backup configurations..."
    docker cp "$(docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q centralserver):/etc/xroad" "$backup_path/centralserver-config"
    docker cp "$(docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q securityserver1):/etc/xroad" "$backup_path/securityserver1-config"
    docker cp "$(docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q securityserver2):/etc/xroad" "$backup_path/securityserver2-config"
    
    # Backup volumes
    print_info "Backup volumes..."
    docker run --rm -v xroad_centralserver_data:/data -v "$(pwd)/$backup_path":/backup ubuntu tar czf /backup/centralserver-data.tar.gz -C /data .
    docker run --rm -v xroad_securityserver1_data:/data -v "$(pwd)/$backup_path":/backup ubuntu tar czf /backup/securityserver1-data.tar.gz -C /data .
    docker run --rm -v xroad_securityserver2_data:/data -v "$(pwd)/$backup_path":/backup ubuntu tar czf /backup/securityserver2-data.tar.gz -C /data .
    
    # Backup SSL certificates
    print_info "Backup SSL certificates..."
    cp -r nginx/ssl "$backup_path/"
    
    # Backup environment files
    print_info "Backup environment files..."
    cp .env "$backup_path/"
    cp env.example "$backup_path/"
    
    # Backup docker-compose files
    print_info "Backup docker-compose files..."
    cp docker-compose.yml "$backup_path/"
    cp -r nginx "$backup_path/"
    
    # Tạo file metadata
    cat > "$backup_path/metadata.txt" << EOF
X-Road Backup Metadata
=====================
Created: $(date)
Version: $(docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec centralserver cat /etc/xroad/VERSION 2>/dev/null || echo "Unknown")
Docker Compose Version: $(docker-compose version --short)
Backup Type: Full System Backup

Services:
- Central Server
- Security Server 1
- Security Server 2
- Test CA
- Information Systems
- Nginx Reverse Proxy

Files:
- centralserver.sql: Central Server database
- securityserver1.sql: Security Server 1 database
- securityserver2.sql: Security Server 2 database
- centralserver-config/: Central Server configuration
- securityserver1-config/: Security Server 1 configuration
- securityserver2-config/: Security Server 2 configuration
- centralserver-data.tar.gz: Central Server data volume
- securityserver1-data.tar.gz: Security Server 1 data volume
- securityserver2-data.tar.gz: Security Server 2 data volume
- ssl/: SSL certificates
- .env: Environment configuration
- docker-compose.yml: Docker Compose configuration
- nginx/: Nginx configuration

Restore Command:
./scripts/backup.sh --restore $backup_name
EOF

    # Tạo archive
    print_info "Tạo archive..."
    cd "$BACKUP_DIR"
    tar czf "${backup_name}.tar.gz" "$backup_name"
    rm -rf "$backup_name"
    cd ..
    
    print_success "Backup đã được tạo: $BACKUP_DIR/${backup_name}.tar.gz"
    
    # Hiển thị thông tin backup
    print_info "Thông tin backup:"
    ls -lh "$BACKUP_DIR/${backup_name}.tar.gz"
    echo ""
    print_info "Để restore backup này, sử dụng:"
    echo "  ./scripts/backup.sh --restore $backup_name"
}

# Hàm restore backup
restore_backup() {
    local backup_name=$1
    local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [ -z "$backup_name" ]; then
        print_error "Vui lòng cung cấp tên backup"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "File backup không tồn tại: $backup_file"
        exit 1
    fi
    
    print_warning "Restore backup sẽ xóa dữ liệu hiện tại!"
    read -p "Bạn có chắc chắn muốn tiếp tục? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Hủy bỏ restore"
        exit 0
    fi
    
    print_info "Restore backup: $backup_name"
    
    # Dừng hệ thống
    print_info "Dừng hệ thống hiện tại..."
    ./scripts/stop.sh --clean
    
    # Giải nén backup
    print_info "Giải nén backup..."
    cd "$BACKUP_DIR"
    tar xzf "${backup_name}.tar.gz"
    cd ..
    
    # Restore databases
    print_info "Restore databases..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d centralserver
    sleep 30
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T centralserver \
        psql -U xroad xroad < "$backup_path/centralserver.sql"
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d securityserver1
    sleep 30
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T securityserver1 \
        psql -U xroad xroad < "$backup_path/securityserver1.sql"
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d securityserver2
    sleep 30
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T securityserver2 \
        psql -U xroad xroad < "$backup_path/securityserver2.sql"
    
    # Restore configurations
    print_info "Restore configurations..."
    docker cp "$backup_path/centralserver-config" "$(docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q centralserver):/etc/xroad"
    docker cp "$backup_path/securityserver1-config" "$(docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q securityserver1):/etc/xroad"
    docker cp "$backup_path/securityserver2-config" "$(docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q securityserver2):/etc/xroad"
    
    # Restore volumes
    print_info "Restore volumes..."
    docker run --rm -v xroad_centralserver_data:/data -v "$(pwd)/$backup_path":/backup ubuntu tar xzf /backup/centralserver-data.tar.gz -C /data
    docker run --rm -v xroad_securityserver1_data:/data -v "$(pwd)/$backup_path":/backup ubuntu tar xzf /backup/securityserver1-data.tar.gz -C /data
    docker run --rm -v xroad_securityserver2_data:/data -v "$(pwd)/$backup_path":/backup ubuntu tar xzf /backup/securityserver2-data.tar.gz -C /data
    
    # Restore SSL certificates
    print_info "Restore SSL certificates..."
    cp -r "$backup_path/ssl" nginx/
    
    # Restore environment files
    print_info "Restore environment files..."
    cp "$backup_path/.env" .
    
    # Khởi động lại hệ thống
    print_info "Khởi động lại hệ thống..."
    ./scripts/start.sh
    
    # Dọn dẹp
    rm -rf "$backup_path"
    
    print_success "Backup đã được restore thành công!"
}

# Hàm liệt kê backups
list_backups() {
    print_info "Danh sách backups:"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        print_warning "Không có backup nào"
        return 0
    fi
    
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null | while read -r line; do
        echo "$line"
    done
}

# Main function
main() {
    local restore_mode=false
    local backup_name=""
    local list_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --restore)
                restore_mode=true
                backup_name="$2"
                shift 2
                ;;
            --list)
                list_mode=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--restore BACKUP_NAME] [--list]"
                echo "  --restore BACKUP_NAME   Restore backup cụ thể"
                echo "  --list                  Liệt kê tất cả backups"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Tạo thư mục backup
    mkdir -p "$BACKUP_DIR"
    
    if [ "$list_mode" = true ]; then
        list_backups
    elif [ "$restore_mode" = true ]; then
        restore_backup "$backup_name"
    else
        create_backup
    fi
}

# Chạy main function
main "$@"
