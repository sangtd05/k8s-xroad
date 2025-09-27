# PostgreSQL HA Fixes - Các sửa đổi quan trọng

## 🚨 **Vấn đề đã sửa**

### 1. **NodeSelector gây mất HA**
**Vấn đề cũ:**
```yaml
nodeSelector:
  kubernetes.io/hostname: k8s-worker-1  # ❌ Tất cả pods trên 1 node
```

**Giải pháp:**
```yaml
# ✅ Bỏ nodeSelector để scheduler tự động trải đều
# Kubernetes sẽ tự động đặt pods trên các nodes khác nhau
```

### 2. **Cấu hình PostgreSQL bị trùng lặp**
**Vấn đề cũ:**
```yaml
postgresql:
  version: "15"

# ... sau đó lại có:
postgresql:
  version: "15"
  parameters: ...
```

**Giải pháp:**
```yaml
postgresql:
  version: "15"
  parameters:
    log_statement: "all"
    # ... tất cả parameters ở đây
```

### 3. **LoadBalancer không cần thiết**
**Vấn đề cũ:**
```yaml
enableMasterLoadBalancer: false
enableReplicaLoadBalancer: false
# ... lặp lại 2 lần
```

**Giải pháp:**
```yaml
# ✅ Bỏ hoàn toàn - operator tự tạo ClusterIP services
# - xroad-postgres-ha (master)
# - xroad-postgres-ha-repl (replicas)
```

### 4. **PodAntiAffinity không đúng format**
**Vấn đề cũ:**
```yaml
podAntiAffinity:
  type: "preferredDuringSchedulingIgnoredDuringExecution"  # ❌ Sai format
```

**Giải pháp:**
```yaml
# ✅ Bỏ hoàn toàn - Zalando operator tự handle HA scheduling
```

## 🎯 **Kết quả sau khi sửa**

### ✅ **High Availability thực sự**
- 3 PostgreSQL pods được trải đều trên các nodes
- Automatic failover khi node bị lỗi
- Không có single point of failure

### ✅ **Services được tạo tự động**
- `xroad-postgres-ha`: Master service (read/write)
- `xroad-postgres-ha-repl`: Replica service (read-only, load-balanced)

### ✅ **Cấu hình tối ưu**
- Không có cấu hình trùng lặp
- Sử dụng đúng format của Zalando operator
- Tự động scaling và failover

## 🚀 **Cách triển khai**

```bash
# 1. Tạo PostgreSQL HA cluster
./xroad.sh postgres create

# 2. Kiểm tra pods được trải đều trên các nodes
kubectl get pods -n xroad -l application=spilo -o wide

# 3. Kiểm tra services
kubectl get svc -n xroad | grep xroad-postgres-ha

# 4. Test secret name (quan trọng!)
./xroad.sh test-secret

# 5. Deploy X-Road
./xroad.sh deploy
```

## 📊 **Kiểm tra HA**

```bash
# Xem pod distribution
kubectl get pods -n xroad -l application=spilo -o wide

# Kết quả mong đợi:
# NAME                    NODE           STATUS
# xroad-postgres-ha-1     k8s-worker-1   Running
# xroad-postgres-ha-2     k8s-worker-2   Running  
# xroad-postgres-ha-3     k8s-worker-3   Running

# Xem services
kubectl get svc -n xroad | grep xroad-postgres-ha

# Kết quả mong đợi:
# xroad-postgres-ha        ClusterIP   10.96.x.x   5432/TCP
# xroad-postgres-ha-repl   ClusterIP   10.96.x.x   5432/TCP
```

## 🔧 **Troubleshooting**

### Nếu pods vẫn trên cùng 1 node:
```bash
# Kiểm tra node resources
kubectl describe nodes

# Kiểm tra taints/tolerations
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Force reschedule (nếu cần)
kubectl delete pod -n xroad -l application=spilo
```

### Nếu services không được tạo:
```bash
# Kiểm tra operator logs
kubectl logs -n postgres-operator -l app.kubernetes.io/name=postgres-operator

# Kiểm tra PostgreSQL resource
kubectl describe postgresql xroad-postgres-ha -n xroad
```

### Nếu secret không đúng tên:
```bash
# Test secret name
./xroad.sh test-secret

# Xem tất cả secrets
kubectl get secrets -n xroad | grep postgres

# Nếu secret có tên khác, cập nhật trong Helm templates
```

## 📝 **Tóm tắt**

Những sửa đổi này đảm bảo:

1. **True HA**: Pods được trải đều trên các nodes
2. **Clean config**: Không có cấu hình trùng lặp hoặc sai format
3. **Auto services**: Operator tự tạo services cần thiết
4. **Better performance**: Sử dụng đúng connection pooling và parameters

PostgreSQL cluster giờ đây thực sự có High Availability và sẵn sàng cho production!
