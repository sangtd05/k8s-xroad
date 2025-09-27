# Central Server Setup Guide

Hướng dẫn chi tiết triển khai Central Server và Master Security Server.

## Tổng quan

Central Server là thành phần trung tâm của hệ thống X-Road, có nhiệm vụ:
- Quản lý danh sách Security Servers
- Quản lý Approved Certificate Authorities (CAs)
- Cung cấp OCSP và TSA services
- Quản lý trust relationships giữa các Security Servers

## Yêu cầu hệ thống

### Hardware
- **CPU**: Tối thiểu 2 cores
- **RAM**: Tối thiểu 4GB (khuyến nghị 8GB)
- **Disk**: Tối thiểu 50GB (khuyến nghị 100GB)
- **Network**: 1Gbps

### Software
- **OS**: Ubuntu 20.04+ hoặc tương đương
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+
- **OpenSSL**: Version 1.1.1+

## Triển khai từng bước

### Bước 1: Chuẩn bị hệ thống

```bash
cd central-server
sudo ./scripts/prepare-host.sh
```

Script này sẽ:
- Cập nhật hệ thống
- Cài đặt Docker và Docker Compose
- Cài đặt các dependencies cần thiết
- Cấu hình UFW firewall cơ bản

### Bước 2: Cài đặt Central Server

```bash
sudo ./scripts/install-cs.sh
```

Script này sẽ:
- Thêm X-Road repository
- Cài đặt Central Server packages
- Cài đặt PostgreSQL
- Khởi động các services cần thiết

### Bước 3: Cấu hình Firewall

```bash
sudo ./scripts/configure-firewall.sh
```

Script này sẽ mở các ports:
- **80/tcp**: HTTP (redirect to HTTPS)
- **443/tcp**: HTTPS
- **4000/tcp**: Central Server UI
- **5500/tcp**: X-Road message protocol
- **5577/tcp**: X-Road management protocol

### Bước 4: Khởi động Master Security Server

```bash
sudo ./scripts/start-master-ss.sh
```

Script này sẽ:
- Tạo Docker volumes
- Tạo file cấu hình `.env`
- Deploy Master Security Server container
- Cấu hình ports và volumes

### Bước 5: Kiểm tra hệ thống

```bash
./scripts/health-check.sh
```

## Cấu hình chi tiết

### Central Server Configuration

Central Server được cài đặt tại `/etc/xroad/` với các file cấu hình chính:
- `serverconf.xml`: Cấu hình server
- `local.conf`: Cấu hình local
- `db.properties`: Cấu hình database

### Master Security Server Configuration

Master Security Server chạy trong Docker container với cấu hình:
- **Image**: `niis/xroad-security-server-sidecar:7.6.2`
- **Admin UI**: `https://127.0.0.1:4001/`
- **Health Check**: `http://127.0.0.1:5588/`

### Database Configuration

Central Server sử dụng PostgreSQL local:
- **Database**: `centerui_production`
- **User**: `centerui`
- **Port**: 5432

## Truy cập và sử dụng

### Central Server UI
- **URL**: `https://<FQDN>:4000/`
- **Default User**: `admin`
- **Default Password**: Được tạo tự động trong quá trình setup

### Master Security Server UI
- **URL**: `https://127.0.0.1:4001/`
- **Credentials**: Xem trong file `compose/.env`

## Cấu hình PKI Services

Sau khi Central Server hoạt động, cần cấu hình PKI services:

### 1. Import CA Chain
1. Truy cập Central Server UI
2. Vào **Configuration** → **Approved CAs**
3. Click **Add CA**
4. Upload file `pki/ca-chain.crt` từ PKI Services

### 2. Cấu hình OCSP
1. Vào **Configuration** → **OCSP Responders**
2. Click **Add OCSP Responder**
3. Nhập URL: `http://<PKI-HOST>:8888`
4. Upload certificate: `pki/ocsp.crt`

### 3. Cấu hình TSA
1. Vào **Configuration** → **Timestamping Services**
2. Click **Add Timestamping Service**
3. Nhập URL: `http://<PKI-HOST>:3000/api/v1/timestamp`
4. Upload certificate: `pki/tsa.crt`

## Monitoring và Maintenance

### Health Checks
```bash
# Kiểm tra Central Server services
systemctl status xroad-center xroad-center-registration-service xroad-center-management-service

# Kiểm tra Master Security Server
docker ps
docker logs xroad-ss-mgmt

# Kiểm tra ports
ss -tlpn | grep -E ":(80|443|4000|4001|5500|5577)"
```

### Logs
```bash
# Central Server logs
journalctl -u xroad-center -f
journalctl -u xroad-center-registration-service -f

# Master Security Server logs
docker logs -f xroad-ss-mgmt
```

### Backup
```bash
# Backup Central Server configuration
sudo tar -czf central-server-backup-$(date +%Y%m%d).tar.gz /etc/xroad

# Backup database
sudo -u postgres pg_dump centerui_production > centerui-backup-$(date +%Y%m%d).sql
```

## Troubleshooting

### Common Issues

#### Central Server không khởi động
```bash
# Kiểm tra logs
journalctl -u xroad-center -n 50

# Kiểm tra cấu hình
sudo xroad-center --check-config

# Restart services
sudo systemctl restart xroad-center
```

#### Master Security Server không kết nối
```bash
# Kiểm tra container logs
docker logs xroad-ss-mgmt

# Kiểm tra network
docker network ls
docker inspect xroad-ss-mgmt

# Restart container
docker restart xroad-ss-mgmt
```

#### Database connection issues
```bash
# Kiểm tra PostgreSQL
sudo systemctl status postgresql
sudo -u postgres psql -c "SELECT version();"

# Kiểm tra connection
sudo -u postgres psql -d centerui_production -c "SELECT 1;"
```

### Performance Tuning

#### Database Optimization
```bash
# Cấu hình PostgreSQL
sudo nano /etc/postgresql/*/main/postgresql.conf

# Tăng shared_buffers
shared_buffers = 256MB

# Tăng work_mem
work_mem = 4MB

# Restart PostgreSQL
sudo systemctl restart postgresql
```

#### Memory Optimization
```bash
# Cấu hình JVM cho Central Server
sudo nano /etc/xroad/center.conf

# Thêm JVM options
JAVA_OPTS="-Xms2g -Xmx4g -XX:+UseG1GC"
```

## Security Considerations

### Firewall Rules
```bash
# Chỉ cho phép access từ trusted networks
sudo ufw allow from 192.168.1.0/24 to any port 4000
sudo ufw allow from 10.0.0.0/8 to any port 4000
```

### SSL/TLS Configuration
- Sử dụng certificates từ trusted CA
- Cấu hình strong cipher suites
- Enable HSTS headers

### Access Control
- Thay đổi default passwords
- Sử dụng strong passwords
- Enable two-factor authentication nếu có thể

## Next Steps

Sau khi Central Server hoạt động:
1. Cài đặt PKI Services
2. Cấu hình CAs, OCSP, TSA
3. Deploy Security Servers trên Kubernetes
4. Register Security Servers với Central Server
5. Test end-to-end communication
