# PostgreSQL HA Setup cho X-Road

## Tổng quan

Hướng dẫn thiết lập PostgreSQL High Availability cluster cho X-Road sử dụng Zalando PostgreSQL Operator.

## Kiến trúc

```
┌─────────────────────────────────────────────────────────────┐
│                PostgreSQL HA Cluster                       │
├─────────────────────────────────────────────────────────────┤
│  Master (Primary)     │  Replica 1        │  Replica 2     │
│  ┌─────────────────┐  │  ┌─────────────┐  │  ┌───────────┐ │
│  │ - Read/Write    │  │  │ - Read Only │  │  │ - Read    │ │
│  │ - WAL Shipping  │  │  │ - Hot Standby│  │  │ - Hot     │ │
│  │ - Failover      │  │  │ - Auto Sync │  │  │   Standby │ │
│  └─────────────────┘  │  └─────────────┘  │  └───────────┘ │
├─────────────────────────────────────────────────────────────┤
│                Connection Pooler                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ - PgBouncer (2 instances)                          │   │
│  │ - Transaction pooling mode                         │   │
│  │ - Max 100 connections per instance                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Triển khai

### 1. Tạo PostgreSQL HA Cluster

```bash
# Sử dụng script tự động
./xroad.sh postgres create

# Hoặc thủ công
kubectl apply -f examples/xroad-postgres-ha.yaml
```

### 2. Kiểm tra trạng thái

```bash
# Kiểm tra cluster
./xroad.sh postgres status

# Xem logs
./xroad.sh postgres logs

# Kết nối database
./xroad.sh postgres connect
```

### 3. Quản lý cluster

```bash
# Scale cluster
./xroad.sh postgres scale 5

# Backup database
./xroad.sh postgres backup

# Restore database
./xroad.sh postgres restore ./backups/postgres/20241201_120000/xroad_backup.sql

# Xem credentials
./xroad.sh postgres credentials
```

## Cấu hình chi tiết

### PostgreSQL Cluster Manifest

File: `examples/xroad-postgres-ha.yaml`

```yaml
apiVersion: acid.zalan.do/v1
kind: postgresql
metadata:
  name: xroad-postgres-ha
  namespace: xroad
spec:
  teamId: "xroad"
  numberOfInstances: 3          # 3 instances cho HA (tự động trải đều trên các nodes)
  volume:
    size: 10Gi                  # Storage cho mỗi instance
  users:
    xroad:                      # User xroad
      - superuser
      - createdb
      - login
  databases:
    xroad: xroad                # Database xroad
  postgresql:
    version: "15"               # PostgreSQL 15
    parameters:                 # Tối ưu hóa performance
      log_statement: "all"
      shared_preload_libraries: "pg_stat_statements"
      # ... các parameters khác
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 2Gi
  enableConnectionPooler: true
  connectionPooler:
    numberOfInstances: 2        # 2 PgBouncer instances
    maxConnections: 100         # Max connections per instance
    mode: "transaction"         # Transaction pooling
```

**Lưu ý quan trọng:**
- **Không có nodeSelector**: Để Kubernetes scheduler tự động trải đều pods trên các nodes
- **Không có podAntiAffinity**: Zalando operator tự động handle HA scheduling
- **Không có LoadBalancer**: Chỉ sử dụng ClusterIP services mặc định

### X-Road Configuration

File: `examples/xroad-3worker-values.yaml`

```yaml
externalDatabase:
  enabled: true
  host: "xroad-postgres-ha.xroad.svc.cluster.local"        # Master service (read/write)
  port: 5432
  database: "xroad"
  username: "xroad"
  password: "xroad123"                                      # Sẽ được override bởi operator
  sslMode: "prefer"
  maxConnections: 100
  connectionTimeout: 30
  idleTimeout: 300
  replicaHost: "xroad-postgres-ha-repl.xroad.svc.cluster.local"  # Replica service (read-only)
  replicaPort: 5432
```

**Services được tạo tự động:**
- `xroad-postgres-ha`: Master service (read/write operations)
- `xroad-postgres-ha-repl`: Replica service (read-only operations, load-balanced)

## Monitoring và Troubleshooting

### 1. Kiểm tra trạng thái cluster

```bash
# PostgreSQL resource
kubectl get postgresql -n xroad

# Pods
kubectl get pods -n xroad -l application=spilo

# Services
kubectl get svc -n xroad | grep xroad-postgres-ha

# PVCs
kubectl get pvc -n xroad | grep xroad-postgres-ha
```

### 2. Kiểm tra logs

```bash
# Logs của tất cả pods
kubectl logs -n xroad -l application=spilo

# Logs của master pod
kubectl logs -n xroad -l application=spilo,spilo-role=master

# Logs của replica pods
kubectl logs -n xroad -l application=spilo,spilo-role=replica
```

### 3. Kết nối database

```bash
# Kết nối trực tiếp
kubectl exec -it -n xroad <master-pod> -- psql -U xroad -d xroad

# Sử dụng script
./xroad.sh postgres connect
```

### 4. Backup và Restore

```bash
# Tạo backup
./xroad.sh postgres backup

# Restore từ backup
./xroad.sh postgres restore ./backups/postgres/20241201_120000/xroad_backup.sql
```

## High Availability Features

### 1. Automatic Failover

- **Master failure**: Tự động promote replica thành master
- **Replica failure**: Tự động tạo replica mới
- **Pod restart**: Tự động recovery

### 2. Connection Pooling

- **PgBouncer**: 2 instances cho load balancing
- **Transaction pooling**: Hiệu quả cho short-lived connections
- **Max connections**: 100 per instance (200 total)

### 3. Data Protection

- **WAL shipping**: Continuous replication
- **Point-in-time recovery**: Từ WAL logs
- **Automated backups**: Hàng ngày

## Scaling

### 1. Scale Instances

```bash
# Scale lên 5 instances
./xroad.sh postgres scale 5

# Scale xuống 2 instances
./xroad.sh postgres scale 2
```

### 2. Scale Resources

Chỉnh sửa manifest và apply:

```yaml
resources:
  requests:
    cpu: 500m        # Tăng từ 250m
    memory: 1Gi      # Tăng từ 512Mi
  limits:
    cpu: 2000m       # Tăng từ 1000m
    memory: 4Gi      # Tăng từ 2Gi
```

## Security

### 1. Network Policies

```yaml
# Chỉ cho phép X-Road pods kết nối
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-network-policy
  namespace: xroad
spec:
  podSelector:
    matchLabels:
      application: spilo
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: xroad-central-server
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: xroad-security-server
```

### 2. Secrets Management

- **Credentials**: Tự động tạo bởi operator với tên `xroad-postgres-ha.credentials.xroad`
- **SSL certificates**: Tự động generate
- **Encryption**: Data at rest và in transit

**Secret structure:**
```bash
kubectl get secret xroad-postgres-ha.credentials.xroad -n xroad -o yaml
```

## Performance Tuning

### 1. PostgreSQL Parameters

```yaml
postgresql:
  parameters:
    shared_buffers: "256MB"
    effective_cache_size: "1GB"
    work_mem: "4MB"
    maintenance_work_mem: "64MB"
    checkpoint_completion_target: 0.9
    wal_buffers: "16MB"
    default_statistics_target: 100
    random_page_cost: 1.1
    effective_io_concurrency: 200
```

### 2. Connection Pooling

```yaml
connectionPooler:
  numberOfInstances: 3          # Tăng số instances
  maxConnections: 200           # Tăng max connections
  mode: "session"               # Session pooling cho long connections
```

## Troubleshooting

### 1. Common Issues

**Cluster không ready:**
```bash
kubectl describe postgresql xroad-postgres-ha -n xroad
kubectl get events -n xroad --sort-by='.lastTimestamp'
```

**Connection refused:**
```bash
kubectl get svc -n xroad | grep xroad-postgres-ha
kubectl get endpoints -n xroad | grep xroad-postgres-ha
```

**Pod crash:**
```bash
kubectl logs -n xroad <pod-name> --previous
kubectl describe pod -n xroad <pod-name>
```

### 2. Debug Commands

```bash
# Kiểm tra cluster status
kubectl get postgresql -n xroad -o yaml

# Kiểm tra pods
kubectl get pods -n xroad -l application=spilo -o wide

# Kiểm tra services
kubectl get svc -n xroad

# Kiểm tra PVCs
kubectl get pvc -n xroad

# Kiểm tra events
kubectl get events -n xroad --sort-by='.lastTimestamp'
```

## Best Practices

1. **Monitoring**: Sử dụng PostgreSQL Operator UI
2. **Backup**: Tạo backup thường xuyên
3. **Testing**: Test failover scenarios
4. **Resources**: Monitor CPU/Memory usage
5. **Security**: Sử dụng Network Policies
6. **Updates**: Cập nhật PostgreSQL version cẩn thận

## Kết luận

PostgreSQL HA cluster cung cấp:

- **High Availability**: 99.9% uptime
- **Scalability**: Dễ dàng scale instances
- **Performance**: Connection pooling và optimization
- **Security**: Encryption và access control
- **Monitoring**: Tích hợp với Kubernetes monitoring

Với cấu hình này, X-Road sẽ có database backend mạnh mẽ và đáng tin cậy.
