# X-Road Deployment trên Cluster 3 Worker Nodes

## Tổng quan

Hướng dẫn triển khai X-Road trên cluster Kubernetes với 1 master node và 3 worker nodes, với chiến lược phân bố tối ưu:

- **k8s-manager**: Master node (không triển khai workload)
- **k8s-worker-1**: Central Server + PostgreSQL
- **k8s-worker-2**: Security Server Primary
- **k8s-worker-3**: Security Server Secondary

## Kiến trúc triển khai

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
│                 │    │                 │    │                 │
│ - Admin UI      │    │ - Admin UI      │    │ - Admin UI      │
│ - Management    │    │ - Consumer      │    │ - Consumer      │
│ - Registration  │    │ - Transport     │    │ - Transport     │
│ - Database      │    │ - OCSP          │    │ - OCSP          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Yêu cầu hệ thống

### Tài nguyên tối thiểu cho mỗi worker node:
- **CPU**: 2+ cores
- **Memory**: 4+ GB RAM
- **Storage**: 20+ GB disk space
- **Network**: 1+ Gbps

### Tài nguyên khuyến nghị:
- **CPU**: 4+ cores
- **Memory**: 8+ GB RAM
- **Storage**: 50+ GB SSD
- **Network**: 10+ Gbps

## Triển khai

### 1. Chuẩn bị môi trường

```bash
# Kiểm tra cluster
kubectl get nodes -o wide

# Kiểm tra tài nguyên nodes
kubectl describe nodes | grep -A 5 "Capacity:"

# Tạo namespace
kubectl create namespace xroad
```

### 2. Triển khai tự động

```bash
# Sử dụng script tự động
chmod +x deploy-3worker.sh
./deploy-3worker.sh

# Hoặc với tùy chọn tùy chỉnh
./deploy-3worker.sh -n xroad -f xroad-3worker-values.yaml
```

### 3. Triển khai thủ công

```bash
# Thêm Helm repositories
helm repo add postgres-operator https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm repo update

# Triển khai PostgreSQL Operator
helm upgrade postgres-operator postgres-operator/postgres-operator \
    --install \
    --create-namespace \
    --namespace postgres-operator \
    --wait \
    --timeout 5m

helm upgrade postgres-operator-ui postgres-operator-ui/postgres-operator-ui \
    --install \
    --namespace postgres-operator \
    --wait \
    --timeout 5m

# Triển khai X-Road
helm install xroad ./helm/xroad \
    --namespace xroad \
    --values xroad-3worker-values.yaml \
    --wait \
    --timeout 15m
```

## Cấu hình chi tiết

### File cấu hình chính: `xroad-3worker-values.yaml`

```yaml
# Central Server - Deploy trên k8s-worker-1
centralServer:
  enabled: true
  nodeSelector:
    kubernetes.io/hostname: k8s-worker-1
  resources:
    limits:
      cpu: 2000m
      memory: 4000Mi
    requests:
      cpu: 500m
      memory: 2000Mi

# Security Server Primary - Deploy trên k8s-worker-2
securityServer:
  enabled: true
  secondaryReplicaCount: 1  # Chỉ 1 secondary trên k8s-worker-3
  nodeSelector:
    kubernetes.io/hostname: k8s-worker-2
  resources:
    limits:
      cpu: 2000m
      memory: 4000Mi
    requests:
      cpu: 500m
      memory: 2000Mi

# PostgreSQL - Deploy trên k8s-worker-1 (cùng với Central Server)
postgresql:
  enabled: true
  nodeSelector:
    kubernetes.io/hostname: k8s-worker-1
  resources:
    limits:
      cpu: 1000m
      memory: 2000Mi
    requests:
      cpu: 250m
      memory: 1000Mi
```

## Kiểm tra triển khai

### 1. Kiểm tra trạng thái pods

```bash
# Xem tất cả pods
kubectl get pods -n xroad -o wide

# Kiểm tra phân bố pods trên các nodes
kubectl get pods -n xroad -o wide --no-headers | awk '{print $7}' | sort | uniq -c
```

### 2. Kiểm tra services

```bash
# Xem tất cả services
kubectl get svc -n xroad

# Kiểm tra endpoints
kubectl get endpoints -n xroad
```

### 3. Kiểm tra logs

```bash
# Central Server logs
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-central-server -f

# Security Server logs
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-security-server -f

# PostgreSQL logs
kubectl logs -n xroad -l postgresql.cnpg.io/cluster=xroad-postgresql -f
```

## Truy cập các dịch vụ

### Central Server (k8s-worker-1)

```bash
# Port forward
kubectl port-forward -n xroad svc/xroad-central-server 4000:4000

# Truy cập: https://localhost:4000
# Credentials: xrd-sys / secret
```

### Security Server (k8s-worker-2)

```bash
# Port forward
kubectl port-forward -n xroad svc/xroad-security-server 4000:4000

# Truy cập: https://localhost:4000
# Credentials: xrd-sys / secret
```

## Monitoring và Troubleshooting

### 1. Kiểm tra tài nguyên nodes

```bash
# Xem tài nguyên sử dụng
kubectl top nodes  # Nếu metrics-server được cài đặt

# Hoặc kiểm tra thủ công
kubectl describe nodes
```

### 2. Kiểm tra persistent volumes

```bash
# Xem persistent volumes
kubectl get pv

# Xem persistent volume claims
kubectl get pvc -n xroad
```

### 3. Debug pods

```bash
# Mô tả pod để xem events
kubectl describe pod -n xroad <pod-name>

# Truy cập shell của pod
kubectl exec -it -n xroad <pod-name> -- /bin/bash

# Xem logs với timestamp
kubectl logs -n xroad <pod-name> --timestamps=true
```

## Scaling và High Availability

### 1. Scale Security Server Secondary

```bash
# Tăng số lượng secondary servers
kubectl scale deployment xroad-security-server-secondary -n xroad --replicas=2

# Hoặc cập nhật values file
helm upgrade xroad ./helm/xroad -n xroad -f xroad-3worker-values.yaml \
    --set securityServer.secondaryReplicaCount=2
```

### 2. Thêm node mới

Nếu thêm worker node mới, có thể cập nhật nodeSelector:

```yaml
# Trong values file
securityServer:
  nodeSelector:
    kubernetes.io/hostname: k8s-worker-4  # Node mới
```

## Backup và Recovery

### 1. Backup database

```bash
# Tạo backup thủ công
kubectl exec -n xroad xroad-postgresql-1 -- pg_dump -U xroad xroad > backup.sql

# Khôi phục từ backup
kubectl exec -i -n xroad xroad-postgresql-1 -- psql -U xroad xroad < backup.sql
```

### 2. Backup configuration

```bash
# Backup Central Server config
kubectl exec -n xroad xroad-central-server-0 -- tar czf - /etc/xroad > central-config.tar.gz

# Backup Security Server config
kubectl exec -n xroad xroad-security-server-primary-0 -- tar czf - /etc/xroad > security-config.tar.gz
```

## Maintenance

### 1. Cập nhật X-Road

```bash
# Cập nhật image version
helm upgrade xroad ./helm/xroad -n xroad -f xroad-3worker-values.yaml \
    --set centralServer.image.tag="7.7.0" \
    --set securityServer.image.primaryTag="7.7.1-primary-ee" \
    --set securityServer.image.secondaryTag="7.7.1-secondary-ee"
```

### 2. Restart services

```bash
# Restart Central Server
kubectl rollout restart statefulset xroad-central-server -n xroad

# Restart Security Server
kubectl rollout restart statefulset xroad-security-server-primary -n xroad
kubectl rollout restart deployment xroad-security-server-secondary -n xroad
```

## Troubleshooting

### Các vấn đề thường gặp:

1. **Pod không khởi động**: Kiểm tra resource limits và node capacity
2. **Database connection failed**: Kiểm tra PostgreSQL cluster status
3. **Service không accessible**: Kiểm tra service type và port configuration
4. **Authentication failed**: Kiểm tra secret configuration

### Lệnh debug hữu ích:

```bash
# Kiểm tra events
kubectl get events -n xroad --sort-by='.lastTimestamp'

# Kiểm tra resource usage
kubectl describe nodes

# Kiểm tra network connectivity
kubectl exec -n xroad xroad-central-server-0 -- ping k8s-worker-2

# Kiểm tra DNS resolution
kubectl exec -n xroad xroad-central-server-0 -- nslookup xroad-postgresql
```

## Kết luận

Với cấu hình này, X-Road sẽ được triển khai tối ưu trên cluster 3 worker nodes:

- **High Availability**: Các thành phần được phân bố trên các nodes khác nhau
- **Performance**: Central Server và PostgreSQL trên cùng node để giảm latency
- **Scalability**: Có thể scale Security Server secondary nodes khi cần
- **Maintainability**: Dễ dàng quản lý và troubleshoot từng thành phần

Triển khai này phù hợp cho môi trường production với yêu cầu high availability và performance tốt.
