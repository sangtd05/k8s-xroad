# X-Road Kubernetes Deployment

A complete X-Road deployment solution for Kubernetes with Central Server and Security Server cluster.

## 🚀 Quick Start

### Deploy X-Road

```bash
# Deploy X-Road on 3-worker cluster
./xroad.sh deploy

# Check deployment status
./xroad.sh status

# View access information
./xroad.sh access
```

### Access Services

```bash
# Central Server Admin Interface
kubectl port-forward -n xroad svc/xroad-central-server 4000:4000
# Open: https://localhost:4000
# Credentials: xrd-sys / secret

# Security Server Admin Interface  
kubectl port-forward -n xroad svc/xroad-security-server 4000:4000
# Open: https://localhost:4000
# Credentials: xrd-sys / secret
```

## 📁 Project Structure

```
x-road-helm/
├── xroad.sh                    # Main management script
├── helm/                       # Helm charts
│   └── xroad/                  # Main X-Road chart
├── scripts/                    # Management scripts
│   ├── deploy-3worker.sh       # Deployment script
│   ├── cleanup.sh              # Full cleanup
│   ├── quick-cleanup.sh        # Quick cleanup
│   ├── status-check.sh         # Status checker
│   └── manage.sh               # Advanced management
├── docs/                       # Documentation
│   └── 3WORKER_DEPLOYMENT.md   # Detailed deployment guide
├── examples/                   # Example configurations
│   ├── xroad-3worker-values.yaml
│   └── docker-compose.yml
└── docker/                     # Docker configurations
    └── central-server/
```

## 🛠️ Management Commands

### Basic Operations

```bash
# Deploy X-Road
./xroad.sh deploy

# Check status
./xroad.sh status

# View logs
./xroad.sh logs central
./xroad.sh logs security
./xroad.sh logs all

# Show access info
./xroad.sh access
```

### Advanced Operations

```bash
# Restart services
./xroad.sh restart

# Scale Security Server
./xroad.sh scale 3

# Create backup
./xroad.sh backup

# Restore from backup
./xroad.sh restore ./backups/20241201_120000

# Cleanup (with confirmation)
./xroad.sh cleanup

# Quick cleanup (no confirmation)
./xroad.sh quick-cleanup
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    X-Road Kubernetes Stack                 │
├─────────────────────────────────────────────────────────────┤
│  Central Server          │  Security Server Cluster        │
│  ┌─────────────────┐    │  ┌─────────────────┐            │
│  │ - Admin UI      │    │  │ Primary Node    │            │
│  │ - Management    │    │  │ - Admin UI      │            │
│  │ - Registration  │    │  │ - Consumer      │            │
│  │ - PostgreSQL    │    │  │ - Transport     │            │
│  └─────────────────┘    │  └─────────────────┘            │
│                         │  ┌─────────────────┐            │
│                         │  │ Secondary Nodes │            │
│                         │  │ - Admin UI      │            │
│                         │  │ - Consumer      │            │
│                         │  │ - Transport     │            │
│                         │  └─────────────────┘            │
├─────────────────────────────────────────────────────────────┤
│                PostgreSQL Cluster                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ - Central Server Database                           │   │
│  │ - Security Server Database                          │   │
│  │ - High Availability                                 │   │
│  │ - Automated Backups                                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.0+
- kubectl configured
- Resources: 8+ CPU cores, 16+ GB RAM, 50+ GB storage

## 🔧 Configuration

### Custom Values

Edit `examples/xroad-3worker-values.yaml` for custom configuration:

```yaml
# Central Server configuration
centralServer:
  enabled: true
  image:
    repository: xroad-centralserver
    tag: "7.6.0"
  resources:
    limits:
      cpu: 2000m
      memory: 4000Mi

# Security Server configuration
securityServer:
  enabled: true
  secondaryReplicaCount: 2
  resources:
    limits:
      cpu: 2000m
      memory: 4000Mi
```

### Node Distribution

- **k8s-worker-1**: Central Server + PostgreSQL
- **k8s-worker-2**: Security Server Primary
- **k8s-worker-3**: Security Server Secondary

## 🐛 Troubleshooting

### Check Status

```bash
# Comprehensive status check
./xroad.sh status

# View logs
./xroad.sh logs all

# Check pod distribution
kubectl get pods -n xroad -o wide
```

### Common Issues

1. **Pods not starting**: Check resources and node capacity
2. **Database connection failed**: Verify PostgreSQL cluster
3. **Service not accessible**: Check service configuration
4. **Authentication failed**: Verify secret configuration

### Debug Commands

```bash
# Check events
kubectl get events -n xroad --sort-by='.lastTimestamp'

# Describe pods
kubectl describe pod -n xroad <pod-name>

# Check resources
kubectl top nodes
kubectl top pods -n xroad
```

## 🔄 Cleanup and Redeploy

### Complete Cleanup

```bash
# Cleanup with confirmation
./xroad.sh cleanup

# Quick cleanup (no confirmation)
./xroad.sh quick-cleanup
```

### Redeploy

```bash
# Deploy again
./xroad.sh deploy
```

## 📚 Documentation

- [Deployment Guide](docs/3WORKER_DEPLOYMENT.md) - Detailed deployment instructions
- [X-Road Documentation](https://docs.x-road.global) - Official X-Road docs
- [X-Road Community](https://x-road.global) - Community support

## 🤝 Support

For issues and questions:
- Check the [deployment guide](docs/3WORKER_DEPLOYMENT.md)
- Run `./xroad.sh status` for diagnostics
- Create an issue in this repository

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.