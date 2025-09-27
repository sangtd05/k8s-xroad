# X-Road Docker Deployment - Simplified

Hệ thống X-Road đơn giản được triển khai bằng Docker với 1 Security Server, sử dụng Docker images từ thư mục Docker hiện có, hỗ trợ truy cập từ bên ngoài.

## 🏗️ Kiến trúc hệ thống

### Thành phần chính:
- **Central Server**: Trung tâm quản lý X-Road (Port: 4000)
- **Security Server**: Máy chủ bảo mật duy nhất (Port: 4001)
- **Test CA**: Cơ quan chứng thực số thử nghiệm (Port: 8888)
- **Information Systems**: Các dịch vụ thông tin
  - REST API (Port: 8082)
  - SOAP API (Port: 8083)
  - OpenAPI (Port: 8084)
- **Mailpit**: Mail server cho thông báo (Port: 8025)
- **Nginx**: Reverse proxy với SSL/TLS (Port: 80/443)

### Mạng lưới:
- **xroad-network**: Mạng bridge cho tất cả containers
- **Subnet**: 172.20.0.0/16

### Docker Images:
- Sử dụng Docker images được build từ thư mục `Docker/`
- Tất cả images được build local từ source code X-Road

## 🚀 Triển khai nhanh

### 1. Yêu cầu hệ thống
- Docker 24.x+
- Docker Compose 2.24.x+
- OpenSSL (để tạo SSL certificate)
- 4GB RAM tối thiểu
- 20GB disk space

### 2. Cài đặt
```bash
# Clone repository
git clone <repository-url>
cd k8s-xroad

# Cài đặt tự động (build images + khởi động)
make install

# Hoặc cài đặt thủ công
cp config.env .env
make build
make ssl
make start-init
```

### 3. Truy cập hệ thống
- **Central Server**: https://localhost:4000
- **Security Server**: https://localhost:4001
- **Test CA**: https://localhost:8888
- **Mailpit**: https://localhost:8025

**Thông tin đăng nhập mặc định:**
- Username: `xrd`
- Password: `secret`

## 📋 Quản lý hệ thống

### Scripts có sẵn:

#### Khởi động hệ thống
```bash
# Khởi động cơ bản
make start

# Khởi động và khởi tạo
make start-init

# Khởi động với SSL mới
make start-ssl

# Build images trước khi khởi động
make build
make start
```

#### Dừng hệ thống
```bash
# Dừng bình thường
make stop

# Dừng và dọn dẹp hoàn toàn
make stop-clean
```

#### Khởi động lại
```bash
# Khởi động lại bình thường
make restart

# Khởi động lại với dọn dẹp
make restart-clean

# Khởi động lại và khởi tạo
make restart-init
```

#### Kiểm tra trạng thái
```bash
# Trạng thái cơ bản
make status

# Trạng thái chi tiết
make status-detailed

# Xem logs
make logs

# Xem logs của service cụ thể
make logs-service SERVICE=cs
```

#### Build và cài đặt
```bash
# Build Docker images từ thư mục Docker
make build

# Cài đặt hoàn chỉnh
make install

# Kiểm tra kết nối
make test
```

## 🌐 Cấu hình truy cập từ xa

### 1. Cấu hình IP và Port
Chỉnh sửa file `.env` (copy từ `config.env`):
```bash
# Cấu hình port mapping
CS_UI_PORT=4000
SS_UI_PORT=4001
SS_PROXY_HTTP_PORT=8080
SS_PROXY_HTTPS_PORT=8443
```

### 2. Cấu hình Firewall
```bash
# Ubuntu/Debian
sudo ufw allow 4000:4001/tcp
sudo ufw allow 8080:8082/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=4000-4001/tcp
sudo firewall-cmd --permanent --add-port=8080-8082/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

### 3. Cấu hình DNS (tùy chọn)
Thêm các A record:
```
centralserver.yourdomain.com    -> YOUR_SERVER_IP
securityserver.yourdomain.com   -> YOUR_SERVER_IP
```

## 🔗 Kết nối Security Server từ xa

### 1. Cấu hình Central Server
```bash
# Chạy script cấu hình
./scripts/setup-remote-ss.sh

# Kiểm tra kết nối
./scripts/setup-remote-ss.sh --check --remote-ip REMOTE_SS_IP
```

### 2. Các bước cấu hình:

#### Trên Central Server:
1. Truy cập https://YOUR_SERVER_IP:4000
2. Đăng nhập với tài khoản `xrd` / `secret`
3. Vào **Management** > **Security Servers**
4. Thêm Security Server mới:
   - Server Code: `REMOTE_SS_001`
   - Address: `REMOTE_SS_IP`
   - Port: `4000`

#### Trên Security Server từ xa:
1. Copy file `remote-ss-config-template.txt` và `remote-ss-setup.sh`
2. Chỉnh sửa file cấu hình:
   ```bash
   CENTRAL_SERVER_ADDRESS=YOUR_SERVER_IP
   SECURITY_SERVER_CODE=REMOTE_SS_001
   SECURITY_SERVER_ADDRESS=REMOTE_SS_IP
   ```
3. Chạy script cấu hình:
   ```bash
   chmod +x remote-ss-setup.sh
   ./remote-ss-setup.sh
   ```

### 3. Kiểm tra kết nối
```bash
# Từ Central Server
curl -k https://REMOTE_SS_IP:4000

# Từ Security Server từ xa
curl -k https://YOUR_SERVER_IP:4000
```

## 🔧 Cấu hình nâng cao

### 1. SSL/TLS
```bash
# Tạo chứng chỉ mới
./scripts/generate-ssl.sh

# Sử dụng chứng chỉ từ CA
# Copy cert.pem và key.pem vào nginx/ssl/
```

### 2. Database
```bash
# Backup database
docker-compose exec centralserver pg_dump -U xroad xroad > backup.sql

# Restore database
docker-compose exec -T centralserver psql -U xroad xroad < backup.sql
```

### 3. Logs
```bash
# Xem logs tất cả services
docker-compose logs -f

# Xem logs service cụ thể
docker-compose logs -f centralserver

# Xem logs với timestamp
docker-compose logs -f -t centralserver
```

### 4. Monitoring
```bash
# Kiểm tra resource usage
docker stats

# Kiểm tra network
docker network ls
docker network inspect xroad-network

# Kiểm tra volumes
docker volume ls
```

## 🐛 Troubleshooting

### 1. Services không khởi động
```bash
# Kiểm tra logs
./scripts/status.sh --logs

# Kiểm tra cấu hình
docker-compose config

# Khởi động lại
./scripts/restart.sh --clean
```

### 2. Không thể truy cập từ xa
```bash
# Kiểm tra firewall
sudo ufw status
sudo netstat -tlnp | grep :4000

# Kiểm tra network
docker network inspect xroad-network

# Kiểm tra nginx
docker-compose logs nginx
```

### 3. SSL issues
```bash
# Kiểm tra certificate
openssl x509 -in nginx/ssl/cert.pem -text -noout

# Tạo certificate mới
./scripts/generate-ssl.sh

# Kiểm tra nginx config
docker-compose exec nginx nginx -t
```

### 4. Database issues
```bash
# Kiểm tra database status
docker-compose exec centralserver pg_isready

# Kiểm tra database logs
docker-compose logs centralserver | grep postgres

# Reset database
./scripts/stop.sh --clean
./scripts/start.sh --init
```

## 📊 Monitoring và Logs

### 1. Health Checks
Tất cả services đều có health check tự động:
- Central Server: https://localhost:4000
- Security Servers: https://localhost:4001, https://localhost:4002
- Test CA: http://localhost:8888/testca/certs
- Information Systems: Các endpoint tương ứng

### 2. Log Files
```bash
# Application logs
docker-compose logs -f

# System logs
journalctl -u docker

# Nginx logs
docker-compose exec nginx tail -f /var/log/nginx/access.log
docker-compose exec nginx tail -f /var/log/nginx/error.log
```

### 3. Performance Monitoring
```bash
# Resource usage
docker stats

# Network traffic
docker-compose exec nginx netstat -i

# Disk usage
docker system df
```

## 🔒 Bảo mật

### 1. Thay đổi mật khẩu mặc định
```bash
# Chỉnh sửa file .env
XROAD_TOKEN_PIN=YourSecurePassword
CENTRALSERVER_DB_PASSWORD=YourSecureDBPassword
SECURITYSERVER1_DB_PASSWORD=YourSecureDBPassword
SECURITYSERVER2_DB_PASSWORD=YourSecureDBPassword
```

### 2. Cấu hình SSL/TLS
- Sử dụng chứng chỉ từ CA uy tín trong production
- Cấu hình cipher suites mạnh
- Bật HSTS và các security headers

### 3. Firewall Rules
```bash
# Chỉ mở các port cần thiết
sudo ufw allow from TRUSTED_IP to any port 4000
sudo ufw allow from TRUSTED_IP to any port 4001
sudo ufw allow from TRUSTED_IP to any port 4002
```

## 🔨 Build Docker Images

### Build tự động
```bash
# Build tất cả images từ thư mục Docker
make build

# Hoặc chạy script trực tiếp
./scripts/build-images.sh
```

### Build thủ công từng image
```bash
# Central Server
docker build -t xroad-centralserver:latest \
  --build-arg PACKAGE_SOURCE=external \
  -f Docker/centralserver/Dockerfile .

# Security Server
docker build -t xroad-securityserver:latest \
  --build-arg PACKAGE_SOURCE=external \
  -f Docker/securityserver/Dockerfile .

# Test CA
docker build -t xroad-testca:latest \
  -f Docker/testca/Dockerfile .

# Example Adapter (SOAP)
docker build -t xroad-example-adapter:latest \
  -f Docker/test-services/example-adapter/Dockerfile .
```

### Kiểm tra images
```bash
# Xem danh sách images
docker images | grep xroad

# Kiểm tra chi tiết image
docker inspect xroad-centralserver:latest
```

## 📚 Tài liệu tham khảo

- [X-Road Official Documentation](https://x-road.global/documentation/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Nginx Configuration](https://nginx.org/en/docs/)
- [Docker Build Documentation](https://docs.docker.com/engine/reference/builder/)

## 🤝 Hỗ trợ

Nếu gặp vấn đề, vui lòng:
1. Kiểm tra logs: `make logs`
2. Kiểm tra trạng thái: `make status-detailed`
3. Build lại images: `make build`
4. Tạo issue với thông tin chi tiết

## 📄 License

MIT License - Xem file LICENSE để biết thêm chi tiết.
