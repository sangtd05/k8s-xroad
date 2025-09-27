# X-Road Helm Charts

This repository contains Helm charts for deploying a complete X-Road infrastructure on Kubernetes, including Central Server and Security Server cluster.

## Overview

X-Road is a distributed data exchange layer between information systems that provides a standardized and secure way to produce and consume services. This Helm chart deployment includes:

- **Central Server**: Manages the global configuration and member information
- **Security Server Cluster**: Handles secure message exchange (Primary + Secondary nodes)
- **PostgreSQL Cluster**: Database backend for both Central Server and Security Servers
- **PostgreSQL Operator**: Manages the PostgreSQL cluster lifecycle

## Architecture

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

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.0+
- kubectl configured to access your cluster
- Sufficient resources:
  - CPU: 8+ cores total
  - Memory: 16+ GB total
  - Storage: 50+ GB total

## Quick Start

### 1. Add Helm Repositories

```bash
# Add PostgreSQL Operator repository
helm repo add postgres-operator https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add postgres-operator-ui https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm repo update
```

### 2. Create Namespace

```bash
kubectl create namespace xroad
```

### 3. Deploy X-Road

```bash
# Deploy with default values
helm install xroad ./helm/xroad -n xroad

# Or deploy with custom values
helm install xroad ./helm/xroad -n xroad -f xroad-values-example.yaml
```

### 4. Check Deployment Status

```bash
# Check all pods
kubectl get pods -n xroad

# Check services
kubectl get svc -n xroad

# Check logs
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-central-server -f
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-security-server -f
```

### 5. Access the Services

#### Central Server Admin Interface

```bash
# Port forward to access admin interface
kubectl port-forward -n xroad svc/xroad-central-server 4000:4000

# Open browser to https://localhost:4000
# Default credentials: xrd-sys / secret
```

#### Security Server Admin Interface

```bash
# Port forward to access admin interface
kubectl port-forward -n xroad svc/xroad-security-server 4000:4000

# Open browser to https://localhost:4000
# Default credentials: xrd-sys / secret
```

## Configuration

### Central Server Configuration

The Central Server can be configured through the `centralServer` section in values.yaml:

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

### Security Server Configuration

The Security Server cluster can be configured through the `securityServer` section:

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

### PostgreSQL Configuration

The PostgreSQL cluster can be configured through the `postgresql` section:

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

## Customization

### Custom Docker Images

To use custom Docker images, update the image configuration:

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

### Custom Configuration Files

You can provide custom configuration files through the `filesData` section:

```yaml
centralServer:
  filesData: |
    custom-config.ini: |
      [admin-service]
      global-configuration-generation-rate-in-seconds = 10
      [configuration-client]
      update-interval = 10
```

### Resource Limits

Adjust resource limits based on your requirements:

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

## Monitoring and Logging

### View Logs

```bash
# Central Server logs
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-central-server -f

# Security Server logs
kubectl logs -n xroad -l app.kubernetes.io/name=xroad-security-server -f

# PostgreSQL logs
kubectl logs -n xroad -l postgresql.cnpg.io/cluster=xroad-postgresql -f
```

### Health Checks

```bash
# Check pod status
kubectl get pods -n xroad

# Check service endpoints
kubectl get endpoints -n xroad

# Check persistent volumes
kubectl get pv
kubectl get pvc -n xroad
```

## Backup and Recovery

### Database Backup

The PostgreSQL cluster supports automated backups to S3:

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

### Manual Backup

```bash
# Create manual backup
kubectl exec -n xroad xroad-postgresql-1 -- pg_dump -U xroad xroad > backup.sql

# Restore from backup
kubectl exec -i -n xroad xroad-postgresql-1 -- psql -U xroad xroad < backup.sql
```

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource limits and node capacity
2. **Database connection issues**: Verify PostgreSQL cluster status
3. **Service not accessible**: Check service type and port configuration
4. **Authentication issues**: Verify secret configuration

### Debug Commands

```bash
# Describe pods for detailed status
kubectl describe pod -n xroad <pod-name>

# Check events
kubectl get events -n xroad --sort-by='.lastTimestamp'

# Check logs with timestamps
kubectl logs -n xroad <pod-name> --timestamps=true

# Access pod shell
kubectl exec -it -n xroad <pod-name> -- /bin/bash
```

## Security Considerations

1. **Change default passwords** in production
2. **Use proper secrets management** (e.g., external-secrets-operator)
3. **Enable network policies** for network segmentation
4. **Use TLS certificates** for external access
5. **Regular security updates** of container images

## Production Deployment

For production deployment, consider:

1. **High Availability**: Deploy across multiple availability zones
2. **Resource Planning**: Allocate sufficient CPU, memory, and storage
3. **Monitoring**: Implement comprehensive monitoring and alerting
4. **Backup Strategy**: Regular automated backups with tested recovery procedures
5. **Security**: Implement proper authentication, authorization, and network security
6. **Scaling**: Plan for horizontal scaling of Security Server nodes

## Support

For issues and questions:

- X-Road Documentation: https://docs.x-road.global
- X-Road Community: https://x-road.global
- GitHub Issues: Create an issue in this repository

## License

This project is licensed under the MIT License - see the LICENSE file for details.