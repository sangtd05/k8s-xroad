# Security Servers on Kubernetes

Hướng dẫn chi tiết triển khai Security Servers trên Kubernetes cluster.

## Tổng quan

Security Servers là thành phần xử lý các giao dịch X-Road, có nhiệm vụ:
- Xử lý các message requests từ clients
- Kết nối với Central Server để quản lý trust relationships
- Lưu trữ logs và monitoring data
- Cung cấp APIs cho client applications

## Kiến trúc

```
┌─────────────────────────────────────────────────────────────┐
│                 Kubernetes Cluster                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ Primary Security│  │Secondary Security│  │ PostgreSQL  │  │
│  │ Server          │  │ Server          │  │ Cluster     │  │
│  │ (Port 4000)     │  │ (Port 4000)     │  │ (3 nodes)   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
│           │                     │                    │       │
│           └─────────────────────┼────────────────────┘       │
│                                 │                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ LoadBalancer    │  │ MetalLB         │  │ Storage     │  │
│  │ (ss-public)     │  │ (IP Pool)       │  │ (PVCs)      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ X-Road Protocol
                              │
┌─────────────────────────────────────────────────────────────┐
│                 Central Server VM                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ Central Server  │  │ Master Security │  │ PKI Services│  │
│  │ (Port 4000)     │  │ Server (4001)   │  │ (OCSP/TSA)  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Yêu cầu hệ thống

### Kubernetes Cluster
- **Control Plane**: 1 node
- **Workers**: Tối thiểu 2 nodes
- **RAM**: 4GB+ per node
- **CPU**: 2+ cores per node
- **Storage**: 100GB+ per node

### Prerequisites
- **MetalLB**: Cho LoadBalancer IPs
- **Zalando Postgres Operator**: Cho PostgreSQL cluster
- **Persistent Volumes**: Cho data storage
- **Network**: Kết nối tới Central Server

## Triển khai từng bước

### Bước 1: Chuẩn bị Kubernetes Cluster

#### Cài đặt MetalLB
```bash
# Deploy MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Chờ MetalLB ready
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
```

#### Cài đặt Zalando Postgres Operator
```bash
# Deploy Postgres Operator
kubectl apply -f https://raw.githubusercontent.com/zalando/postgres-operator/v1.10.0/manifests/postgres-operator.yaml

# Chờ Operator ready
kubectl wait --namespace postgres-operator --for=condition=ready pod --selector=name=postgres-operator --timeout=90s
```

### Bước 2: Deploy Security Servers

```bash
cd security-servers
./deploy.sh
```

Script này sẽ:
1. Tạo namespace `xroad`
2. Cấu hình MetalLB address pool
3. Tạo secrets cho X-Road
4. Tạo Persistent Volume Claims
5. Deploy PostgreSQL cluster
6. Deploy Primary và Secondary Security Servers
7. Cấu hình Network Policies

### Bước 3: Kiểm tra Deployment

```bash
# Kiểm tra pods
kubectl -n xroad get pods -o wide

# Kiểm tra services
kubectl -n xroad get svc

# Kiểm tra PostgreSQL cluster
kubectl -n xroad get postgresql

# Kiểm tra logs
kubectl -n xroad logs -f deploy/ss-primary
kubectl -n xroad logs -f deploy/ss-secondary
```

## Cấu hình chi tiết

### Secrets Configuration

#### X-Road Secrets
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: xroad-secrets
type: Opaque
stringData:
  db-password: "CHANGE_ME_DB_PASS"
  admin-password: "CHANGE_ME_ADMIN_PASS"
  token-pin: "CHANGE_ME_PIN"
```

#### Database Properties
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

### Storage Configuration

#### Primary Security Server Storage
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: etc-xroad-primary-pvc
  namespace: xroad
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

#### Secondary Security Server Storage
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: etc-xroad-secondary-pvc
  namespace: xroad
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### Database Configuration

#### PostgreSQL Cluster
```yaml
apiVersion: "acid.zalan.do/v1"
kind: postgresql
metadata:
  name: xroad-pg
  namespace: xroad
spec:
  teamId: "xroad"
  numberOfInstances: 3
  postgresql:
    version: "16"
    parameters:
      synchronous_commit: "on"
  patroni:
    synchronous_mode: true
    synchronous_mode_strict: false
  volume:
    size: 50Gi
  users:
    xroad_admin: ["superuser", "createdb"]
    xroad_app: []
  databases:
    serverconf: xroad_app
    messagelog: xroad_app
    opmonitor: xroad_app
```

### Security Server Configuration

#### Primary Security Server
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ss-primary
  namespace: xroad
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ss-primary
  template:
    metadata:
      labels:
        app: ss-primary
    spec:
      nodeSelector:
        kubernetes.io/hostname: worker-1
      containers:
        - name: sidecar
          image: niis/xroad-security-server-sidecar:7.6.2-primary
          imagePullPolicy: IfNotPresent
          envFrom:
            - secretRef:
                name: xroad-secrets
          ports:
            - containerPort: 4000
              name: admin
            - containerPort: 5588
              name: health
            - containerPort: 22
              name: ssh
          volumeMounts:
            - name: etc-xroad
              mountPath: /etc/xroad
            - name: var-xroad
              mountPath: /var/lib/xroad
            - name: db-props
              mountPath: /etc/xroad/db.properties
              subPath: db.properties
          resources:
            requests:
              cpu: "1000m"
              memory: "3Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"
          readinessProbe:
            httpGet:
              path: "/"
              port: 5588
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: "/"
              port: 5588
            initialDelaySeconds: 60
            periodSeconds: 20
      volumes:
        - name: etc-xroad
          persistentVolumeClaim:
            claimName: etc-xroad-primary-pvc
        - name: var-xroad
          persistentVolumeClaim:
            claimName: var-xroad-primary-pvc
        - name: db-props
          secret:
            secretName: xroad-db-properties
```

## Kết nối với Central Server

### Bước 1: Download Configuration Anchor

1. Truy cập Central Server UI: `https://<CS-FQDN>:4000/`
2. Vào **Configuration** → **Internal Configuration**
3. Download **Internal Configuration Anchor**

### Bước 2: Import Anchor vào Primary Security Server

1. Port-forward tới Primary Security Server:
   ```bash
   kubectl -n xroad port-forward deploy/ss-primary 4000:4000
   ```

2. Truy cập Primary Security Server UI: `https://127.0.0.1:4000/`

3. Import configuration anchor:
   - Vào **Configuration** → **System Parameters**
   - Upload file anchor đã download

4. Complete initial setup:
   - Generate authentication key
   - Generate signing key
   - Generate certificate request

### Bước 3: Register Security Server

1. Từ Central Server UI:
   - Vào **Security Servers**
   - Click **Add Security Server**
   - Nhập thông tin Security Server
   - Upload certificate request

2. Approve registration từ Central Server

3. Download approved certificate và import vào Security Server

### Bước 4: Secondary Security Server Sync

Secondary Security Server sẽ tự động sync từ Primary:
- Không cần cấu hình thêm
- Kiểm tra logs để đảm bảo sync thành công

## Monitoring và Troubleshooting

### Health Checks

#### Pod Status
```bash
# Kiểm tra tất cả pods
kubectl -n xroad get pods

# Kiểm tra pod details
kubectl -n xroad describe pod <pod-name>

# Kiểm tra pod logs
kubectl -n xroad logs <pod-name> -f
```

#### Service Status
```bash
# Kiểm tra services
kubectl -n xroad get svc

# Kiểm tra endpoints
kubectl -n xroad get endpoints

# Test service connectivity
kubectl -n xroad port-forward svc/ss-primary 4000:4000
curl -k https://127.0.0.1:4000/
```

#### Database Status
```bash
# Kiểm tra PostgreSQL cluster
kubectl -n xroad get postgresql

# Kiểm tra PostgreSQL pods
kubectl -n xroad get pods -l application=spilo

# Kết nối database
kubectl -n xroad exec -it postgres-xroad-pg-0 -- psql -U xroad_app -d serverconf
```

### Common Issues

#### Pod không khởi động
```bash
# Kiểm tra events
kubectl -n xroad get events --sort-by=.metadata.creationTimestamp

# Kiểm tra pod logs
kubectl -n xroad logs <pod-name> --previous

# Kiểm tra resource limits
kubectl -n xroad describe pod <pod-name>
```

#### Database connection issues
```bash
# Kiểm tra PostgreSQL logs
kubectl -n xroad logs postgres-xroad-pg-0

# Kiểm tra database connectivity
kubectl -n xroad exec -it postgres-xroad-pg-0 -- psql -U xroad_app -d serverconf -c "SELECT 1;"

# Kiểm tra secrets
kubectl -n xroad get secret xroad-db-properties -o yaml
```

#### Network connectivity issues
```bash
# Kiểm tra network policies
kubectl -n xroad get networkpolicies

# Kiểm tra service connectivity
kubectl -n xroad exec -it <pod-name> -- curl -k https://ss-primary:4000/

# Kiểm tra DNS resolution
kubectl -n xroad exec -it <pod-name> -- nslookup ss-primary
```

### Performance Monitoring

#### Resource Usage
```bash
# Kiểm tra resource usage
kubectl -n xroad top pods
kubectl -n xroad top nodes

# Kiểm tra resource limits
kubectl -n xroad describe pod <pod-name>
```

#### Database Performance
```bash
# Kết nối database và kiểm tra performance
kubectl -n xroad exec -it postgres-xroad-pg-0 -- psql -U xroad_app -d serverconf

# Kiểm tra active connections
SELECT count(*) FROM pg_stat_activity;

# Kiểm tra database size
SELECT pg_size_pretty(pg_database_size('serverconf'));
```

## Scaling và High Availability

### Horizontal Scaling

#### Scale Security Servers
```bash
# Scale Primary Security Server
kubectl -n xroad scale deployment ss-primary --replicas=3

# Scale Secondary Security Server
kubectl -n xroad scale deployment ss-secondary --replicas=3
```

#### Load Balancing
```bash
# Cấu hình LoadBalancer service
kubectl -n xroad expose deployment ss-primary --type=LoadBalancer --name=ss-primary-lb

# Kiểm tra external IP
kubectl -n xroad get svc ss-primary-lb
```

### Vertical Scaling

#### Tăng Resource Limits
```yaml
resources:
  requests:
    cpu: "2000m"
    memory: "6Gi"
  limits:
    cpu: "4000m"
    memory: "8Gi"
```

#### Database Scaling
```yaml
spec:
  numberOfInstances: 5
  postgresql:
    parameters:
      max_connections: 200
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
```

## Backup và Recovery

### Database Backup
```bash
# Backup PostgreSQL cluster
kubectl -n xroad exec postgres-xroad-pg-0 -- pg_dump -U xroad_app serverconf > backup-serverconf-$(date +%Y%m%d).sql
kubectl -n xroad exec postgres-xroad-pg-0 -- pg_dump -U xroad_app messagelog > backup-messagelog-$(date +%Y%m%d).sql
kubectl -n xroad exec postgres-xroad-pg-0 -- pg_dump -U xroad_app opmonitor > backup-opmonitor-$(date +%Y%m%d).sql
```

### Configuration Backup
```bash
# Backup X-Road configuration
kubectl -n xroad exec deploy/ss-primary -- tar -czf /tmp/xroad-config.tar.gz /etc/xroad
kubectl -n xroad cp ss-primary-xxx:/tmp/xroad-config.tar.gz ./xroad-config-backup-$(date +%Y%m%d).tar.gz
```

### Disaster Recovery
```bash
# Restore database
kubectl -n xroad exec -i postgres-xroad-pg-0 -- psql -U xroad_app -d serverconf < backup-serverconf-20240101.sql

# Restore configuration
kubectl -n xroad cp xroad-config-backup-20240101.tar.gz ss-primary-xxx:/tmp/
kubectl -n xroad exec deploy/ss-primary -- tar -xzf /tmp/xroad-config-backup-20240101.tar.gz -C /
kubectl -n xroad restart deployment ss-primary
```

## Security Considerations

### Network Security
- Sử dụng Network Policies để restrict traffic
- Cấu hình firewall rules
- Sử dụng TLS/SSL cho tất cả communications

### Access Control
- Sử dụng RBAC cho Kubernetes access
- Cấu hình strong passwords
- Enable audit logging

### Data Protection
- Encrypt data at rest
- Sử dụng secure storage classes
- Regular backup và test recovery

## Next Steps

Sau khi Security Servers hoạt động:
1. Test end-to-end communication
2. Cấu hình monitoring và alerting
3. Setup backup và disaster recovery
4. Performance tuning
5. Security hardening
