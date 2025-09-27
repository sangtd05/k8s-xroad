# X-Road Kubernetes Deployment Guide

Hướng dẫn triển khai X-Road hoàn chỉnh lên Kubernetes sử dụng Helm charts.

## Tổng quan

Dự án này cung cấp một giải pháp triển khai X-Road hoàn chỉnh trên Kubernetes bao gồm:

- **Central Server**: Quản lý cấu hình toàn cục và thông tin thành viên
- **Security Server Cluster**: Xử lý trao đổi tin nhắn bảo mật (Primary + Secondary nodes)
- **PostgreSQL Cluster**: Cơ sở dữ liệu backend cho cả Central Server và Security Servers
- **PostgreSQL Operator**: Quản lý vòng đời PostgreSQL cluster

## Kiến trúc

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Central Server │    │ Security Server │    │ Security Server │
│                 │    │    (Primary)    │    │   (Secondary)   │
│  - Admin UI     │    │                 │    │                 │
│  - Management   │    │ - Admin UI      │    │ - Admin UI      │
│  - Registration │    │ - Consumer      │    │ - Consumer      │
│  - PostgreSQL   │    │ - Transport     │    │ - Transport     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ PostgreSQL      │
                    │    Cluster      │
                    │                 │
                    │ - Central DB    │
                    │ - Security DB   │
                    └─────────────────┘
```

## Yêu cầu hệ thống

- Kubernetes cluster (1.19+)
- Helm 3.0+
- kubectl được cấu hình để truy cập cluster
- Tài nguyên đủ:
  - CPU: 8+ cores tổng cộng
  - Memory: 16+ GB tổng cộng
  - Storage: 50+ GB tổng cộng

## Triển khai nhanh

### 1. Chuẩn bị môi trường

```bash
# Clone repository
git clone <repository-url>
cd x-road-helm

# Tạo namespace
kubectl create namespace xroad
```

### 2. Triển khai với script tự động

```bash
# Triển khai với cấu hình mặc định
./deploy.sh

# Triển khai với namespace tùy chỉnh
./deploy.sh -n my-xroad

# Triển khai với file values tùy chỉnh
./deploy.sh -f custom-values.yaml

# Dry run để xem trước
./deploy.sh -d
```

### 3. Triển khai thủ công

```bash
# Thêm Helm repositories
helm repo add postgres-operator https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add postgres-operator-ui https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm repo update

# Triển khai X-Road
helm install xroad ./helm/xroad -n xroad -f xroad-values-example.yaml
```

### 4. Kiểm tra trạng thái

```bash
# Kiểm tra pods
kubectl get pods -n xroad

# Kiểm tra services
kubectl get svc -n xroad

# Xem logs
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-central-server -f
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-security-server -f
```

## Truy cập các dịch vụ

### Central Server Admin Interface

```bash
# Port forward
kubectl port-forward -n xroad svc/xroad-central-server 4000:4000

# Mở trình duyệt: https://localhost:4000
# Thông tin đăng nhập mặc định: xrd-sys / secret
```

### Security Server Admin Interface

```bash
# Port forward
kubectl port-forward -n xroad svc/xroad-security-server 4000:4000

# Mở trình duyệt: https://localhost:4000
# Thông tin đăng nhập mặc định: xrd-sys / secret
```

## Cấu hình

### Central Server

Cấu hình Central Server thông qua section `centralServer` trong values.yaml:

```yaml
centralServer:
  enabled: true
  image:
    repository: xroad-centralserver
    tag: "7.6.0"
  ports:
    admin: 4000
    management: 4001
    registration: 4002
  service:
    type: NodePort
    adminNodePort: 30060
  resources:
    limits:
      cpu: 2000m
      memory: 4000Mi
```

### Security Server Cluster

Cấu hình Security Server cluster thông qua section `securityServer`:

```yaml
securityServer:
  enabled: true
  image:
    repository: niis/xroad-security-server-sidecar
    primaryTag: "7.6.1-primary-ee"
    secondaryTag: "7.6.1-secondary-ee"
  secondaryReplicaCount: 2
  service:
    type: NodePort
    adminNodePort: 30050
    consumerNodePort: 30051
```

### PostgreSQL Cluster

Cấu hình PostgreSQL cluster thông qua section `postgresql`:

```yaml
postgresql:
  enabled: true
  database:
    name: "xroad"
    user: "xroad"
    password: "xroad123"
  persistence:
    size: 20Gi
  backup:
    enabled: true
    s3:
      bucket: "my-xroad-backups"
      region: "us-west-2"
```

## Tùy chỉnh

### Sử dụng Docker Images tùy chỉnh

```yaml
centralServer:
  image:
    repository: your-registry/xroad-centralserver
    tag: "custom-tag"

securityServer:
  image:
    repository: your-registry/xroad-security-server-sidecar
    primaryTag: "custom-primary-tag"
    secondaryTag: "custom-secondary-tag"
```

### File cấu hình tùy chỉnh

```yaml
centralServer:
  filesData: |
    custom-config.ini: |
      [admin-service]
      global-configuration-generation-rate-in-seconds = 10
      [configuration-client]
      update-interval = 10
```

### Điều chỉnh tài nguyên

```yaml
centralServer:
  resources:
    limits:
      cpu: 4000m
      memory: 8000Mi
    requests:
      cpu: 1000m
      memory: 4000Mi

securityServer:
  resources:
    limits:
      cpu: 4000m
      memory: 8000Mi
    requests:
      cpu: 1000m
      memory: 4000Mi
```

## Monitoring và Logging

### Xem logs

```bash
# Central Server logs
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-central-server -f

# Security Server logs
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-security-server -f

# PostgreSQL logs
kubectl logs -n xroad -l postgresql.cnpg.io/cluster=xroad-postgresql -f
```

### Health checks

```bash
# Kiểm tra trạng thái pods
kubectl get pods -n xroad

# Kiểm tra service endpoints
kubectl get endpoints -n xroad

# Kiểm tra persistent volumes
kubectl get pv
kubectl get pvc -n xroad
```

## Backup và Recovery

### Backup tự động

PostgreSQL cluster hỗ trợ backup tự động lên S3:

```yaml
postgresql:
  backup:
    enabled: true
    s3:
      bucket: "my-xroad-backups"
      region: "us-west-2"
      accessKey: "AKIAIOSFODNN7EXAMPLE"
      secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

### Backup thủ công

```bash
# Tạo backup thủ công
kubectl exec -n xroad xroad-postgresql-1 -- pg_dump -U xroad xroad > backup.sql

# Khôi phục từ backup
kubectl exec -i -n xroad xroad-postgresql-1 -- psql -U xroad xroad < backup.sql
```

## Xử lý sự cố

### Các vấn đề thường gặp

1. **Pods không khởi động**: Kiểm tra resource limits và dung lượng node
2. **Lỗi kết nối database**: Xác minh trạng thái PostgreSQL cluster
3. **Service không truy cập được**: Kiểm tra service type và cấu hình port
4. **Lỗi xác thực**: Xác minh cấu hình secret

### Lệnh debug

```bash
# Mô tả chi tiết pods
kubectl describe pod -n xroad <pod-name>

# Kiểm tra events
kubectl get events -n xroad --sort-by='.lastTimestamp'

# Xem logs với timestamp
kubectl logs -n xroad <pod-name> --timestamps=true

# Truy cập shell của pod
kubectl exec -it -n xroad <pod-name> -- /bin/bash
```

## Triển khai Production

Để triển khai production, cần xem xét:

1. **High Availability**: Triển khai trên nhiều availability zones
2. **Resource Planning**: Phân bổ đủ CPU, memory, và storage
3. **Monitoring**: Triển khai monitoring và alerting toàn diện
4. **Backup Strategy**: Backup tự động thường xuyên với quy trình recovery đã test
5. **Security**: Triển khai xác thực, phân quyền và bảo mật mạng phù hợp
6. **Scaling**: Lập kế hoạch scaling ngang cho Security Server nodes

## Test Local với Docker Compose

Để test local trước khi triển khai lên Kubernetes:

```bash
# Khởi động tất cả services
docker-compose up -d

# Kiểm tra trạng thái
docker-compose ps

# Xem logs
docker-compose logs -f

# Dừng services
docker-compose down
```

## Cập nhật và Upgrade

### Cập nhật Helm chart

```bash
# Cập nhật chart
helm upgrade xroad ./helm/xroad -n xroad -f xroad-values-example.yaml

# Cập nhật với values mới
helm upgrade xroad ./helm/xroad -n xroad -f new-values.yaml
```

### Cập nhật Docker images

```yaml
# Trong values.yaml
centralServer:
  image:
    tag: "7.7.0"  # Version mới

securityServer:
  image:
    primaryTag: "7.7.1-primary-ee"
    secondaryTag: "7.7.1-secondary-ee"
```

## Hỗ trợ

Để được hỗ trợ:

- X-Road Documentation: https://docs.x-road.global
- X-Road Community: https://x-road.global
- GitHub Issues: Tạo issue trong repository này

## License

Dự án này được cấp phép theo MIT License - xem file LICENSE để biết thêm chi tiết.
