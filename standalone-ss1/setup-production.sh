#!/bin/bash

# Production Setup Script for SS1 Standalone
# ===========================================

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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root for production setup"
        exit 1
    fi
}

# Create production directories
create_directories() {
    log_info "Creating production directories..."
    
    mkdir -p /opt/xroad/ss1/{data,config,postgres,softhsm}
    mkdir -p /opt/xroad/ss1/nginx/ssl
    mkdir -p /var/log/xroad-ss1
    
    # Set proper permissions
    chown -R 999:999 /opt/xroad/ss1/data
    chown -R 999:999 /opt/xroad/ss1/config
    chown -R 999:999 /opt/xroad/ss1/softhsm
    chown -R 998:998 /opt/xroad/ss1/postgres
    
    log_success "Production directories created"
}

# Generate SSL certificates
generate_ssl_certs() {
    log_info "Generating SSL certificates..."
    
    if [ ! -f /opt/xroad/ss1/nginx/ssl/cert.pem ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /opt/xroad/ss1/nginx/ssl/key.pem \
            -out /opt/xroad/ss1/nginx/ssl/cert.pem \
            -subj "/C=VN/ST=Hanoi/L=Hanoi/O=X-Road/OU=IT/CN=ss1.localhost"
        
        chmod 600 /opt/xroad/ss1/nginx/ssl/key.pem
        chmod 644 /opt/xroad/ss1/nginx/ssl/cert.pem
        
        log_success "SSL certificates generated"
    else
        log_info "SSL certificates already exist"
    fi
}

# Create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/xroad-ss1.service << EOF
[Unit]
Description=X-Road Security Server SS1
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/xroad/ss1
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xroad-ss1.service
    
    log_success "Systemd service created and enabled"
}

# Setup firewall rules
setup_firewall() {
    log_info "Setting up firewall rules..."
    
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 4300/tcp
        ufw allow 4310/tcp
        log_success "UFW firewall rules configured"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=4300/tcp
        firewall-cmd --permanent --add-port=4310/tcp
        firewall-cmd --reload
        log_success "FirewallD rules configured"
    else
        log_warning "No firewall manager found. Please configure firewall manually"
    fi
}

# Create monitoring script
create_monitoring_script() {
    log_info "Creating monitoring script..."
    
    cat > /opt/xroad/ss1/monitor.sh << 'EOF'
#!/bin/bash

# X-Road SS1 Monitoring Script

check_service() {
    local service_name=$1
    local url=$2
    
    if curl -f -k -s "$url" > /dev/null 2>&1; then
        echo "✓ $service_name is healthy"
        return 0
    else
        echo "✗ $service_name is unhealthy"
        return 1
    fi
}

echo "X-Road SS1 Health Check - $(date)"
echo "=================================="

# Check SS1 frontend
check_service "SS1 Frontend" "https://localhost:4300"

# Check SS1 proxy
check_service "SS1 Proxy" "http://localhost:4310"

# Check Docker container
if docker ps | grep -q "ss1-production"; then
    echo "✓ SS1 Container is running"
else
    echo "✗ SS1 Container is not running"
fi

echo "=================================="
EOF

    chmod +x /opt/xroad/ss1/monitor.sh
    
    # Add to crontab for regular monitoring
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/xroad/ss1/monitor.sh >> /var/log/xroad-ss1/monitor.log 2>&1") | crontab -
    
    log_success "Monitoring script created and scheduled"
}

# Create backup script
create_backup_script() {
    log_info "Creating backup script..."
    
    cat > /opt/xroad/ss1/backup.sh << 'EOF'
#!/bin/bash

# X-Road SS1 Backup Script

BACKUP_DIR="/opt/xroad/ss1/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="ss1_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating backup: $BACKUP_FILE"

# Stop SS1
docker compose -f docker-compose.prod.yml down

# Create backup
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    /opt/xroad/ss1/data \
    /opt/xroad/ss1/config \
    /opt/xroad/ss1/postgres \
    /opt/xroad/ss1/softhsm

# Start SS1
docker compose -f docker-compose.prod.yml up -d

echo "Backup completed: $BACKUP_DIR/$BACKUP_FILE"

# Clean old backups (keep last 7 days)
find "$BACKUP_DIR" -name "ss1_backup_*.tar.gz" -mtime +7 -delete

echo "Old backups cleaned"
EOF

    chmod +x /opt/xroad/ss1/backup.sh
    
    # Add to crontab for daily backup
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/xroad/ss1/backup.sh >> /var/log/xroad-ss1/backup.log 2>&1") | crontab -
    
    log_success "Backup script created and scheduled"
}

# Main setup function
main() {
    log_info "Starting production setup for X-Road SS1..."
    
    check_root
    create_directories
    generate_ssl_certs
    create_systemd_service
    setup_firewall
    create_monitoring_script
    create_backup_script
    
    log_success "Production setup completed!"
    echo ""
    log_info "Next steps:"
    echo "1. Copy your configuration files to /opt/xroad/ss1/"
    echo "2. Update .env file with your production settings"
    echo "3. Start the service: systemctl start xroad-ss1"
    echo "4. Check status: systemctl status xroad-ss1"
    echo "5. View logs: journalctl -u xroad-ss1 -f"
}

# Run main function
main "$@"
