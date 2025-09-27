# X-Road Kubernetes Deployment

## 🚀 Tổng quan

Dự án triển khai X-Road trên Kubernetes với PostgreSQL High Availability, bao gồm:

- **X-Road Central Server**: Quản lý danh sách thành viên và cấu hình
- **X-Road Security Server**: Xử lý giao tiếp bảo mật (Primary + Secondary)
- **PostgreSQL HA Cluster**: Cơ sở dữ liệu với tính sẵn sàng cao
- **Management Scripts**: Tự động hóa triển khai và quản lý

## 🏗️ Kiến trúc

```
┌─────────────────────────────────────────────────────────────┐
│                    k8s-manager (Master)                    │
│                  (Control Plane Only)                      │
└─────────────────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────▼────────┐    ┌────────▼────────┐    ┌────────▼────────┐
│ k8s-worker-1   │    │ k8s-worker-2    │    │ k8s-worker-3    │
│                 │    │                 │    │                 │
│ Central Server  │    │ Security Server │    │ Security Server │
│ + PostgreSQL    │    │ (Primary)       │    │ (Secondary)     │
│ (Master)        │    │                 │    │                 │
│                 │    │ - Admin UI      │    │ - Admin UI      │
│ - Admin UI      │    │ - Consumer      │    │ - Consumer      │
│ - Management    │    │ - Transport     │    │ - Transport     │
│ - Registration  │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📋 Yêu cầu hệ thống

### Kubernetes Cluster
- **Master Node**: 1 node (Control Plane)
- **Worker Nodes**: 3+ nodes
- **Kubernetes Version**: 1.20+
- **Storage**: Local storage hoặc NFS

### Prerequisites
- `kubectl` (v1.20+)
- `helm` (v3.0+)
- `curl` (để tải PostgreSQL Operator)
- Quyền admin trên cluster

### Resources
- **CPU**: 8+ cores
- **RAM**: 16+ GB
- **Storage**: 50+ GB

## 🚀 Quy trình triển khai hoàn chỉnh

### Bước 1: Chuẩn bị môi trường

```bash
# 1. Clone repository
git clone <repository-url>
cd k8s-xroad

# 2. Cấp quyền thực thi cho scripts
chmod +x xroad.sh
chmod +x scripts/*.sh

# 3. Kiểm tra kết nối Kubernetes
kubectl cluster-info
kubectl get nodes
```

### Bước 2: Tạo PersistentVolumes (nếu cần)

```bash
# Tạo PersistentVolumes cho PostgreSQL HA cluster
./xroad.sh create-pvs

# Kiểm tra PVs đã tạo
kubectl get pv | grep xroad-postgres
```

### Bước 3: Triển khai PostgreSQL HA

```bash
# Tạo PostgreSQL HA cluster
./xroad.sh postgres create

# Kiểm tra trạng thái PostgreSQL
./xroad.sh postgres status

# Kết nối database để kiểm tra
./xroad.sh postgres connect
```

### Bước 4: Triển khai X-Road

```bash
# Triển khai X-Road với PostgreSQL HA
./xroad.sh deploy

# Kiểm tra trạng thái deployment
./xroad.sh status
```

### Bước 5: Kiểm tra và truy cập

```bash
# Xem logs để đảm bảo không có lỗi
./xroad.sh logs all

# Kiểm tra access information
./xroad.sh access

# Test kết nối database
./xroad.sh postgres connect
```

### Bước 6: Cấu hình X-Road

```bash
# Port forward để truy cập Admin UI
kubectl port-forward -n xroad svc/xroad-central-server 4000:4000
kubectl port-forward -n xroad svc/xroad-security-server 4001:4000

# Truy cập:
# Central Server: https://localhost:4000
# Security Server: https://localhost:4001
# Credentials: xrd-sys / secret
```

## 📁 Cấu trúc dự án

```
k8s-xroad/
├── README.md                   # Tài liệu chính (quy trình triển khai hoàn chỉnh)
├── xroad.sh                    # Script chính
├── helm/                       # Helm charts
│   └── xroad/                  # Main X-Road chart
├── scripts/                    # Management scripts
│   ├── deploy-3worker.sh       # Deployment script
│   ├── manage.sh               # Advanced management
│   └── status-check.sh         # Status checker
└── examples/                   # Example configurations
    ├── xroad-3worker-values.yaml
    └── xroad-postgres-ha.yaml
```

## 🛠️ Quản lý và vận hành

### Xem trạng thái

```bash
# Trạng thái tổng quan
./xroad.sh status

# Trạng thái PostgreSQL
./xroad.sh postgres status

# Logs chi tiết
./xroad.sh logs central
./xroad.sh logs security
./xroad.sh logs all
```

### Scale và Restart

```bash
# Scale Security Server secondary nodes
./xroad.sh scale 3

# Restart tất cả services
./xroad.sh restart

# Restart từng service riêng lẻ
kubectl rollout restart deployment/xroad-central-server -n xroad
kubectl rollout restart deployment/xroad-security-server-primary -n xroad
kubectl rollout restart deployment/xroad-security-server-secondary -n xroad
```

### Backup và Restore

```bash
# Tạo backup
./xroad.sh backup

# Restore từ backup
./xroad.sh restore ./backups/latest

# Manual backup
kubectl exec -n xroad xroad-central-server-0 -- tar czf - /etc/xroad > central-config.tar.gz
kubectl exec -n xroad xroad-security-server-primary-0 -- tar czf - /etc/xroad > security-config.tar.gz
kubectl exec -n postgres-operator xroad-postgresql-1 -- pg_dump -U xroad xroad > database.sql
```

### Cleanup

```bash
# Cleanup với xác nhận
./xroad.sh cleanup

# Quick cleanup (không xác nhận)
./xroad.sh quick-cleanup

# Cleanup tất cả (bao gồm PostgreSQL Operator)
./xroad.sh cleanup -a
```

## ⚙️ Cấu hình

### Helm Values

Chỉnh sửa `examples/xroad-3worker-values.yaml`:

```yaml
# External PostgreSQL configuration
externalDatabase:
  enabled: true
  host: "xroad-postgres-ha.xroad.svc.cluster.local"
  port: 5432
  database: "xroad"
  username: "xroad"
  password: ""  # Sẽ được override bởi secret

# Replica configuration for read-only operations
replicaHost: "xroad-postgres-ha-repl.xroad.svc.cluster.local"
replicaPort: 5432

# Resource limits
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

### PostgreSQL HA Configuration

Chỉnh sửa `examples/xroad-postgres-ha.yaml`:

```yaml
spec:
  numberOfInstances: 3
  volume:
    size: 10Gi
    storageClass: "xroad-storage"
  users:
    xroad:
      - superuser
      - createdb
      - login
  databases:
    xroad: xroad
  postgresql:
    version: "15"
    parameters:
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      maintenance_work_mem: "64MB"
```

## 🔧 Troubleshooting

### 1. PostgreSQL PVC stuck in Pending

**Triệu chứng**: `kubectl get pvc` hiển thị `Pending`

**Nguyên nhân**: StorageClass `xroad-storage` sử dụng `no-provisioner`

**Giải pháp**:
```bash
# Tạo PersistentVolumes thủ công
./xroad.sh postgres create-pvs

# Kiểm tra StorageClass
kubectl get storageclass
kubectl get pvc -n xroad
```

### 2. Central Server không kết nối được database

**Triệu chứng**: Central Server pod crash hoặc pending

**Nguyên nhân**: Secret name không đúng

**Giải pháp**:
```bash
# Kiểm tra secret
kubectl get secrets -n xroad | grep xroad-postgres

# Secret đúng phải là: xroad-postgres-ha.credentials.xroad
# Nếu sai, sửa trong Helm templates
```

### 3. Helm không tải được chart từ GitHub

**Triệu chứng**: `Error: file does not appear to be a gzipped archive`

**Nguyên nhân**: GitHub blob URL không phải raw file

**Giải pháp**: Script đã được sửa để dùng `curl` tải raw files

### 4. PostgreSQL parameter validation error

**Triệu chứng**: `Invalid value: "integer"`

**Nguyên nhân**: `track_activity_query_size` phải là string

**Giải pháp**: Đã sửa trong manifest:
```yaml
track_activity_query_size: "2048"  # String, không phải integer
```

### 5. Pod không start được

**Kiểm tra**:
```bash
# Xem events
kubectl get events -n xroad --sort-by='.lastTimestamp'

# Xem logs
kubectl logs -n xroad <pod-name>

# Xem describe
kubectl describe pod -n xroad <pod-name>
```

## 📊 Monitoring

### Resource Usage

```bash
# Xem resource usage
kubectl top pods -n xroad
kubectl top nodes

# Xem resource requests/limits
kubectl describe pods -n xroad
```

### Health Checks

```bash
# Check all services
kubectl get all -n xroad
kubectl get pvc -n xroad
kubectl get secrets -n xroad

# Check PostgreSQL
kubectl get postgresql -n xroad
kubectl get pods -n xroad -l application=spilo
```

### Logs Collection

```bash
# Collect all logs for debugging
mkdir -p debug-logs
kubectl logs -n xroad --all-containers=true > debug-logs/xroad-logs.txt
kubectl describe pods -n xroad > debug-logs/pod-descriptions.txt
kubectl get events -n xroad > debug-logs/events.txt
```

## 🔒 Security

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: xroad-network-policy
  namespace: xroad
spec:
  podSelector:
    matchLabels:
      app: xroad
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: xroad
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: xroad
```

### RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: xroad-service-account
  namespace: xroad
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: xroad
  name: xroad-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
```

## 🚀 Performance Tuning

### PostgreSQL

```yaml
postgresql:
  parameters:
    shared_buffers: "256MB"
    effective_cache_size: "1GB"
    maintenance_work_mem: "64MB"
    checkpoint_completion_target: 0.9
    wal_buffers: "16MB"
    default_statistics_target: 100
    max_connections: 200
    work_mem: "4MB"
```

### X-Road

```yaml
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 4Gi

# JVM tuning
env:
  - name: JAVA_OPTS
    value: "-Xms1g -Xmx2g -XX:+UseG1GC"
```

## 🔄 Maintenance

### Rolling Updates

```bash
# Update Central Server
kubectl rollout restart deployment/xroad-central-server -n xroad

# Update Security Server
kubectl rollout restart deployment/xroad-security-server-primary -n xroad
kubectl rollout restart deployment/xroad-security-server-secondary -n xroad

# Check rollout status
kubectl rollout status deployment/xroad-central-server -n xroad
```

### Database Maintenance

```bash
# Connect to database
./xroad.sh postgres connect

# Vacuum database
VACUUM ANALYZE;

# Check database size
SELECT pg_size_pretty(pg_database_size('xroad'));

# Check connections
SELECT count(*) FROM pg_stat_activity;
```

### Backup Strategy

```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups/$DATE"

mkdir -p "$BACKUP_DIR"

# Backup configurations
kubectl exec -n xroad xroad-central-server-0 -- tar czf - /etc/xroad > "$BACKUP_DIR/central-config.tar.gz"
kubectl exec -n xroad xroad-security-server-primary-0 -- tar czf - /etc/xroad > "$BACKUP_DIR/security-config.tar.gz"

# Backup database
kubectl exec -n postgres-operator xroad-postgresql-1 -- pg_dump -U xroad xroad > "$BACKUP_DIR/database.sql"

echo "Backup completed: $BACKUP_DIR"
```

## 📞 Support

### Logs Collection

```bash
# Collect all logs for support
mkdir -p support-logs
kubectl logs -n xroad --all-containers=true > support-logs/xroad-logs.txt
kubectl describe pods -n xroad > support-logs/pod-descriptions.txt
kubectl get events -n xroad > support-logs/events.txt
kubectl get all -n xroad > support-logs/resources.txt
```

### Health Check Script

```bash
#!/bin/bash
echo "=== X-Road Health Check ==="
echo "Date: $(date)"
echo ""

echo "=== Kubernetes Cluster ==="
kubectl cluster-info
echo ""

echo "=== Nodes ==="
kubectl get nodes
echo ""

echo "=== X-Road Pods ==="
kubectl get pods -n xroad
echo ""

echo "=== PostgreSQL ==="
kubectl get postgresql -n xroad
kubectl get pods -n xroad -l application=spilo
echo ""

echo "=== Services ==="
kubectl get svc -n xroad
echo ""

echo "=== PVCs ==="
kubectl get pvc -n xroad
echo ""

echo "=== Recent Events ==="
kubectl get events -n xroad --sort-by='.lastTimestamp' | tail -10
```

## 🎯 Quick Commands Reference

```bash
# Deployment
./xroad.sh deploy                    # Deploy X-Road
./xroad.sh postgres create          # Create PostgreSQL HA
./xroad.sh create-pvs               # Create PersistentVolumes

# Status & Monitoring
./xroad.sh status                   # Check status
./xroad.sh postgres status          # Check PostgreSQL
./xroad.sh logs all                 # View all logs

# Management
./xroad.sh restart                  # Restart services
./xroad.sh scale 3                  # Scale Security Server
./xroad.sh backup                   # Create backup
./xroad.sh restore ./backups/latest # Restore backup

# Cleanup
./xroad.sh cleanup                  # Cleanup with confirmation
./xroad.sh quick-cleanup            # Quick cleanup
./xroad.sh cleanup -a               # Cleanup everything

# Access
kubectl port-forward -n xroad svc/xroad-central-server 4000:4000
kubectl port-forward -n xroad svc/xroad-security-server 4001:4000
```

---

**Lưu ý**: Tài liệu này được cập nhật thường xuyên. Vui lòng kiểm tra phiên bản mới nhất và đảm bảo tuân thủ các best practices về security và performance.