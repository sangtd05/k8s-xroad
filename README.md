# X-Road Kubernetes Deployment

This directory contains all the necessary files to deploy X-Road on Kubernetes with 3 worker nodes.

## Prerequisites

- Kubernetes cluster with 1 master and 3 worker nodes
- kubectl configured to access the cluster
- At least 4 CPU cores and 8GB RAM per worker node
- 50GB storage per worker node

## Directory Structure
k8s-deployment/
├── namespaces/
│ └── namespace.yaml
├── storage/
│ ├── storage-class.yaml
│ └── persistent-volumes.yaml
├── postgresql/
│ └── postgresql.yaml
├── central-server/
│ └── central-server.yaml
├── security-server/
│ └── security-server-sidecar.yaml
├── monitoring/
│ ├── prometheus.yaml
│ └── grafana.yaml
├── configmaps/
│ └── configmap.yaml
├── secrets/
│ └── secret.yaml
└── scripts/
├── deploy.sh
└── cleanup.sh

## Deployment Steps

1. Make scripts executable:
   ```bash
   chmod +x scripts/*.sh
   ```

2. Deploy X-Road:
   ```bash
   ./scripts/deploy.sh
   ```

3. Check deployment status:
   ```bash
   kubectl get pods -n xroad
   kubectl get svc -n xroad
   ```

4. Clean up (if needed):
   ```bash
   ./scripts/cleanup.sh
   ```

## Services

- **Central Server**: Internal service for X-Road management
- **Security Server Sidecar**: LoadBalancer service for external access
- **PostgreSQL**: Database service
- **Prometheus**: Monitoring service
- **Grafana**: Dashboard service

## Ports

- 5500: X-Road messaging
- 5577: OCSP responder
- 8443: Consumer information system
- 4000: Admin interface
- 5588: Health check
- 3000: Grafana dashboard
- 9090: Prometheus metrics

## Troubleshooting

- Check pod logs: `kubectl logs -f <pod-name> -n xroad`
- Check pod status: `kubectl describe pod <pod-name> -n xroad`
- Check persistent volumes: `kubectl get pv`
- Check storage classes: `kubectl get storageclass`