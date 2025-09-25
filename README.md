# X-Road Kubernetes Deployment

## Kiến trúc 4 Node

### Node Layout:
- **Master Node**: Kubernetes control plane
- **Worker Node 1**: Central Server + PostgreSQL (CS Database)
- **Worker Node 2**: Security Server Primary + PostgreSQL (SS Database - Read/Write)
- **Worker Node 3**: Security Server Secondary + PostgreSQL (SS Database - Read Only)

### Database Replication:
- SS Primary database (Read/Write) ↔ SS Secondary database (Read Only)
- SS Primary giao tiếp chính với Central Server

## Cấu trúc thư mục:
```
k8s-xroad-deployment/
├── 01-namespace/
├── 02-secrets/
├── 03-configmaps/
├── 04-databases/
├── 05-central-server/
├── 06-security-server/
├── 07-networking/
├── 08-monitoring/
└── 09-deployment-scripts/
```

## Triển khai:
1. Tạo namespace và secrets
2. Deploy databases với replication
3. Deploy Central Server
4. Deploy Security Server Primary
5. Deploy Security Server Secondary
6. Cấu hình networking và monitoring
