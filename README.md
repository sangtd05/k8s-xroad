# X-Road Kubernetes Deployment

Dự án triển khai X-Road trên Kubernetes với kiến trúc 3 tầng: Central Server, Security Servers và PKI Services.

## Kiến trúc tổng thể

```
┌─────────────────────────────────────────────────────────────┐
│                    Central Server VM                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ Central Server  │  │ Master Security │  │ PKI Services│  │
│  │ (Port 4000)     │  │ Server (4001)   │  │ (OCSP/TSA)  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Configuration Anchor
                              │
┌─────────────────────────────────────────────────────────────┐
│                 Kubernetes Cluster                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ Primary Security│  │Secondary Security│  │ PostgreSQL  │  │
│  │ Server          │  │ Server          │  │ Cluster     │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Cấu trúc dự án

- **`central-server/`** - Central Server và Master Security Server (VM)
- **`security-servers/`** - Security Servers trên Kubernetes
- **`pki-services/`** - PKI Services (CA, OCSP, TSA)
- **`docs/`** - Documentation chi tiết
- **`scripts/`** - Deployment scripts tổng thể

## Triển khai nhanh

### 1. Central Server (VM)
```bash
cd central-server
sudo ./deploy.sh
```

### 2. PKI Services
```bash
cd pki-services
sudo ./setup.sh
```

### 3. Security Servers (Kubernetes)
```bash
cd security-servers
./deploy.sh
```

## Documentation

- [Central Server Setup](docs/central-server.md)
- [Security Servers Setup](docs/security-servers.md)
- [PKI Services Setup](docs/pki-services.md)
- [Troubleshooting](docs/troubleshooting.md)

## Yêu cầu hệ thống

- **Central Server VM**: Ubuntu 20.04+, 4GB RAM, 50GB disk
- **Kubernetes**: 1 control-plane + 2 workers, MetalLB, Zalando Postgres Operator
- **Network**: Firewall rules cho ports 80, 443, 4000, 5500, 5577, 8888, 3000
