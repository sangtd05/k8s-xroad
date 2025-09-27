# Security Servers on Kubernetes

Triển khai Security Servers trên Kubernetes cluster với High Availability.

## Tổng quan

Security Servers xử lý các giao dịch X-Road và kết nối với Central Server. Kiến trúc bao gồm:
- **Primary Security Server**: Instance chính xử lý requests
- **Secondary Security Server**: Instance dự phòng, tự động sync từ Primary
- **PostgreSQL Cluster**: Database HA cho Security Servers
- **MetalLB**: LoadBalancer cho external access

## Yêu cầu hệ thống

- **Kubernetes**: 1 control-plane + 2 workers
- **MetalLB**: Cho LoadBalancer IPs
- **Zalando Postgres Operator**: Cho PostgreSQL cluster
- **Storage**: Persistent volumes cho data
- **Network**: Kết nối tới Central Server

## Triển khai

### 1. Chuẩn bị Kubernetes
```bash
# Cài đặt MetalLB (nếu chưa có)
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Cài đặt Zalando Postgres Operator
kubectl apply -f https://raw.githubusercontent.com/zalando/postgres-operator/v1.10.0/manifests/postgres-operator.yaml
```

### 2. Deploy Security Servers
```bash
./deploy.sh
```

### 3. Kiểm tra deployment
```bash
kubectl -n xroad get pods -o wide
kubectl -n xroad get svc
```

## Cấu hình

### Secrets
Cần tạo các secrets trước khi deploy:
```bash
# Tạo secrets từ template
./scripts/create-secrets.sh

# Hoặc tạo manual
kubectl create secret generic xroad-secrets \
  --from-literal=db-password=CHANGE_ME_DB_PASS \
  --from-literal=admin-password=CHANGE_ME_ADMIN_PASS \
  --from-literal=token-pin=CHANGE_ME_PIN
```

### Database Configuration
File `secrets/db-properties.yaml` chứa cấu hình database:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: xroad-db-properties
type: Opaque
stringData:
  db.properties: |
    serverconf.hibernate.connection.password=CHANGE_ME_DB_PASS
    messagelog.hibernate.connection.password=CHANGE_ME_DB_PASS
    opmonitor.hibernate.connection.password=CHANGE_ME_DB_PASS
```

### Node Selection
Cập nhật `nodeSelector` trong deployment files để phù hợp với cluster:
```yaml
nodeSelector:
  kubernetes.io/hostname: k8s-worker-1  # Thay đổi theo tên node
```

## Kết nối với Central Server

### 1. Download Configuration Anchor
- Truy cập Central Server UI: `https://<CS-FQDN>:4000/`
- Download internal configuration anchor

### 2. Import Anchor vào Primary Security Server
- Port-forward tới Primary: `kubectl -n xroad port-forward deploy/ss-primary 4000:4000`
- Truy cập: `https://127.0.0.1:4000/`
- Import configuration anchor
- Generate keys và certificates
- Register Security Server

### 3. Secondary tự động sync
- Secondary Security Server sẽ tự động sync từ Primary
- Không cần cấu hình thêm

## Monitoring và Troubleshooting

### Health Checks
```bash
# Kiểm tra pods
kubectl -n xroad get pods

# Kiểm tra logs
kubectl -n xroad logs -f deploy/ss-primary
kubectl -n xroad logs -f deploy/ss-secondary

# Kiểm tra health endpoint
kubectl -n xroad port-forward deploy/ss-primary 5588:5588
curl http://127.0.0.1:5588
```

### Database
```bash
# Kiểm tra PostgreSQL cluster
kubectl -n xroad get postgresql
kubectl -n xroad describe postgresql xroad-pg

# Kết nối database
kubectl -n xroad exec -it postgres-xroad-pg-0 -- psql -U xroad_app -d serverconf
```

### Network
```bash
# Kiểm tra services
kubectl -n xroad get svc
kubectl -n xroad get endpoints

# Kiểm tra network policies
kubectl -n xroad get networkpolicies
```

## Scaling

### Horizontal Scaling
```bash
# Scale Primary Security Server
kubectl -n xroad scale deployment ss-primary --replicas=2

# Scale Secondary Security Server
kubectl -n xroad scale deployment ss-secondary --replicas=2
```

### Vertical Scaling
Cập nhật resource limits trong deployment files:
```yaml
resources:
  requests:
    cpu: "2000m"
    memory: "6Gi"
  limits:
    cpu: "4000m"
    memory: "8Gi"
```

## Backup và Recovery

### Database Backup
```bash
# Backup PostgreSQL
kubectl -n xroad exec postgres-xroad-pg-0 -- pg_dump -U xroad_app serverconf > backup-serverconf.sql
kubectl -n xroad exec postgres-xroad-pg-0 -- pg_dump -U xroad_app messagelog > backup-messagelog.sql
```

### Configuration Backup
```bash
# Backup X-Road configuration
kubectl -n xroad exec deploy/ss-primary -- tar -czf /tmp/xroad-config.tar.gz /etc/xroad
kubectl -n xroad cp ss-primary-xxx:/tmp/xroad-config.tar.gz ./xroad-config-backup.tar.gz
```