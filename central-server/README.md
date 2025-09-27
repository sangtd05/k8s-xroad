# Central Server + Master Security Server

Triển khai Central Server và Master Security Server trên một VM riêng biệt.

## Tổng quan

Central Server là thành phần trung tâm của hệ thống X-Road, quản lý:
- Danh sách Security Servers
- Approved Certificate Authorities (CAs)
- OCSP và TSA services
- Trust relationships

Master Security Server được sử dụng để quản lý Central Server thông qua giao diện web.

## Yêu cầu hệ thống

- **OS**: Ubuntu 20.04+ hoặc tương đương
- **RAM**: Tối thiểu 4GB
- **Disk**: Tối thiểu 50GB
- **Network**: Ports 80, 443, 4000, 5500, 5577
- **Docker**: Để chạy Master Security Server

## Triển khai

### 1. Chuẩn bị hệ thống
```bash
sudo ./scripts/prepare-host.sh
```

### 2. Cài đặt Central Server
```bash
sudo ./scripts/install-cs.sh
```

### 3. Cấu hình Firewall
```bash
sudo ./scripts/configure-firewall.sh
```

### 4. Khởi động Master Security Server
```bash
sudo ./scripts/start-master-ss.sh
```

### 5. Kiểm tra hệ thống
```bash
./scripts/health-check.sh
```

## Truy cập

- **Central Server UI**: `https://<FQDN>:4000/`
- **Master Security Server UI**: `https://127.0.0.1:4001/`

## Cấu hình

### Environment Variables
File `compose/.env` chứa các thông tin cấu hình:
- `XROAD_TOKEN_PIN`: PIN cho token signing
- `XROAD_ADMIN_USER`: Username admin
- `XROAD_ADMIN_PASSWORD`: Password admin

### Database
Central Server sử dụng PostgreSQL local để lưu trữ:
- Cấu hình Central Server
- Metadata của Security Servers
- Trust relationships

## Troubleshooting

### Kiểm tra services
```bash
systemctl status xroad-center xroad-center-registration-service xroad-center-management-service
```

### Kiểm tra Docker containers
```bash
docker ps
docker logs xroad-ss-mgmt
```

### Kiểm tra ports
```bash
ss -tlpn | grep -E ":(80|443|4000|4001|5500|5577)"
```

## Bước tiếp theo

Sau khi Central Server hoạt động:
1. Cài đặt PKI Services
2. Cấu hình CAs, OCSP, TSA trong Central Server
3. Deploy Security Servers trên Kubernetes
4. Register Security Servers với Central Server