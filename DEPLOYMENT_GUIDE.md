# X-Road Kubernetes Deployment Guide

## 🏗️ Kiến trúc 4 Node

### Node Layout:
- **Master Node**: Kubernetes control plane
- **Worker Node 1**: Central Server + PostgreSQL (CS Database)
- **Worker Node 2**: Security Server Primary + PostgreSQL (SS Database - Read/Write)
- **Worker Node 3**: Security Server Secondary + PostgreSQL (SS Database - Read Only)

### Database Replication:
- SS Primary database (Read/Write) ↔ SS Secondary database (Read Only)
- SS Primary giao tiếp chính với Central Server

## 📋 Yêu cầu hệ thống

### Kubernetes Cluster:
- **Master Node**: 2 CPU, 4GB RAM, 20GB Storage
- **Worker Node 1**: 4 CPU, 8GB RAM, 50GB Storage
- **Worker Node 2**: 4 CPU, 8GB RAM, 50GB Storage  
- **Worker Node 3**: 4 CPU, 8GB RAM, 50GB Storage

### Software Requirements:
- Kubernetes 1.20+
- kubectl 1.20+
- Storage Class: `standard`
- Load Balancer support
- NGINX Ingress Controller

## 🚀 Triển khai

### Bước 1: Chuẩn bị cluster
```bash
# Kiểm tra cluster
kubectl cluster-info
kubectl get nodes

# Đảm bảo node names đúng:
# - worker-node-1
# - worker-node-2  
# - worker-node-3
```

### Bước 2: Cập nhật node selectors
Chỉnh sửa các file YAML để đảm bảo node selectors phù hợp với cluster của bạn:

```yaml
# Trong các file deployment, thay đổi:
nodeSelector:
  kubernetes.io/hostname: worker-node-1  # Thay đổi theo tên node thực tế
```

### Bước 3: Cập nhật secrets
```bash
# Cập nhật passwords trong 02-secrets/secrets.yaml
# Thay thế các giá trị base64 encoded bằng passwords thực tế
```

### Bước 4: Cập nhật certificates
```bash
# Thay thế placeholder certificates trong xroad-tls-secret
# Sử dụng certificates thực tế cho production
```

### Bước 5: Triển khai
```bash
# Chạy script triển khai
cd k8s-xroad
./09-deployment-scripts/deploy.sh

# Hoặc triển khai từng bước:
kubectl apply -f 01-namespace/
kubectl apply -f 02-secrets/
kubectl apply -f 03-configmaps/
kubectl apply -f 04-databases/
kubectl apply -f 05-central-server/
kubectl apply -f 06-security-server/
kubectl apply -f 07-networking/
kubectl apply -f 08-monitoring/
```

## 🔍 Kiểm tra triển khai

### Kiểm tra trạng thái:
```bash
# Sử dụng script kiểm tra
./09-deployment-scripts/check-status.sh

# Hoặc kiểm tra thủ công:
kubectl get pods -n xroad
kubectl get services -n xroad
kubectl get pvc -n xroad
```

### Kiểm tra logs:
```bash
# Central Server
kubectl logs -n xroad -l app=central-server

# Security Server Primary
kubectl logs -n xroad -l app=security-server-primary

# Security Server Secondary
kubectl logs -n xroad -l app=security-server-secondary

# Databases
kubectl logs -n xroad -l app=cs-postgres
kubectl logs -n xroad -l app=ss-postgres-primary
kubectl logs -n xroad -l app=ss-postgres-secondary
```

## 🌐 Truy cập services

### Load Balancer IPs:
```bash
# Lấy external IPs
kubectl get services -n xroad --field-selector=spec.type=LoadBalancer

# Security Server Primary (Main communication)
kubectl get service ss-primary-lb -n xroad

# Security Server Secondary (Read-only)
kubectl get service ss-secondary-lb -n xroad
```

### Ingress URLs:
- Central Server: https://cs.xroad.local
- Security Server Primary: https://ss-primary.xroad.local
- Security Server Secondary: https://ss-secondary.xroad.local

## ⚙️ Cấu hình sau triển khai

### 1. Cấu hình DNS:
```bash
# Thêm vào /etc/hosts hoặc DNS server:
<LoadBalancer-IP> cs.xroad.local
<LoadBalancer-IP> ss-primary.xroad.local
<LoadBalancer-IP> ss-secondary.xroad.local
```

### 2. Khởi tạo X-Road:
1. Truy cập Central Server admin interface
2. Cấu hình instance identifier
3. Tạo member classes và members
4. Cấu hình security servers
5. Thiết lập certificates và keys

### 3. Cấu hình Security Servers:
1. Truy cập Security Server admin interfaces
2. Cấu hình connection với Central Server
3. Tạo authentication và signing certificates
4. Cấu hình services và access rights

## 📊 Monitoring

### Prometheus Metrics:
- Service health status
- Database connections
- Message processing rates
- Error rates

### Grafana Dashboards:
- X-Road Services Status
- Database Performance
- Network Traffic
- Error Monitoring

### Log Aggregation:
- Centralized logging với Fluentd
- Elasticsearch integration
- Kibana dashboards

## 🔧 Troubleshooting

### Common Issues:

1. **Pods không start được:**
   ```bash
   kubectl describe pod -n xroad <pod-name>
   kubectl logs -n xroad <pod-name>
   ```

2. **Database connection issues:**
   ```bash
   # Kiểm tra database services
   kubectl get endpoints -n xroad
   
   # Test connection
   kubectl exec -n xroad -it <pod-name> -- psql -h <db-service> -U <user> -d <database>
   ```

3. **Load balancer không có external IP:**
   ```bash
   # Kiểm tra cloud provider configuration
   kubectl get service -n xroad ss-primary-lb -o yaml
   ```

4. **SSL/TLS issues:**
   ```bash
   # Kiểm tra certificates
   kubectl get secret -n xroad xroad-tls-secret -o yaml
   ```

## 🧹 Cleanup

### Xóa toàn bộ deployment:
```bash
./09-deployment-scripts/cleanup.sh
```

### Xóa thủ công:
```bash
kubectl delete namespace xroad
```

## 📚 Tài liệu tham khảo

- [X-Road Documentation](https://docs.x-road.global)
- [X-Road Security Server Sidecar](https://github.com/nordic-institute/X-Road/tree/develop/sidecar)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [PostgreSQL Replication](https://www.postgresql.org/docs/current/high-availability.html)

## 🆘 Support

Nếu gặp vấn đề:
1. Kiểm tra logs và status
2. Xem troubleshooting section
3. Tham khảo X-Road documentation
4. Liên hệ X-Road community
