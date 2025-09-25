# X-Road Kubernetes Deployment Scripts

## Scripts Overview

### 1. `deploy.sh` - Main Deployment Script
Deploys the complete X-Road infrastructure on Kubernetes.

**Usage:**
```bash
./deploy.sh                    # Deploy everything
./deploy.sh status             # Show deployment status
./deploy.sh clean              # Clean up all resources
./deploy.sh help               # Show help
```

**What it does:**
- Creates namespace and basic resources
- Deploys secrets and configmaps
- Sets up databases with replication
- Deploys Central Server
- Deploys Security Server Primary and Secondary
- Configures networking and load balancers
- Sets up monitoring and logging

### 2. `cleanup.sh` - Cleanup Script
Removes all X-Road resources from the cluster.

**Usage:**
```bash
./cleanup.sh                   # Remove everything
./cleanup.sh help              # Show help
```

**What it does:**
- Deletes all X-Road resources in reverse order
- Removes namespace and all associated resources
- Waits for complete cleanup

### 3. `check-status.sh` - Status Check Script
Checks the status of all X-Road components.

**Usage:**
```bash
./check-status.sh              # Check everything
./check-status.sh pods         # Check only pods
./check-status.sh services     # Check only services
./check-status.sh logs         # Check only logs
./check-status.sh help         # Show help
```

**What it checks:**
- Namespace existence
- Pod status and health
- Service configuration
- Persistent volume claims
- Ingress configuration
- Load balancer status
- Recent logs for errors

## Prerequisites

1. **Kubernetes Cluster**: 4-node cluster with:
   - 1 Master node
   - 3 Worker nodes (worker-node-1, worker-node-2, worker-node-3)

2. **kubectl**: Configured to access your cluster

3. **Storage Class**: `standard` storage class available

4. **Load Balancer**: Support for LoadBalancer services

5. **Ingress Controller**: NGINX ingress controller installed

## Deployment Order

The deployment follows this order to ensure dependencies are met:

1. **Namespace & Basic Resources** (01-namespace/)
2. **Secrets & ConfigMaps** (02-secrets/, 03-configmaps/)
3. **Databases** (04-databases/)
4. **Central Server** (05-central-server/)
5. **Security Servers** (06-security-server/)
6. **Networking** (07-networking/)
7. **Monitoring** (08-monitoring/)

## Node Assignment

- **Master Node**: Kubernetes control plane only
- **Worker Node 1**: Central Server + CS Database
- **Worker Node 2**: Security Server Primary + SS Database (Read/Write)
- **Worker Node 3**: Security Server Secondary + SS Database (Read Only)

## Database Replication

- SS Primary database (Read/Write) ↔ SS Secondary database (Read Only)
- SS Primary communicates with Central Server
- Automatic failover and replication setup

## Troubleshooting

### Common Issues

1. **Pods stuck in Pending state**
   - Check node selector configuration
   - Verify node names match your cluster
   - Check resource availability

2. **Database connection issues**
   - Verify database services are running
   - Check database credentials in secrets
   - Ensure network policies allow communication

3. **Load balancer not getting external IP**
   - Check if your cluster supports LoadBalancer services
   - Verify cloud provider configuration
   - Check firewall rules

4. **SSL/TLS certificate issues**
   - Update xroad-tls-secret with valid certificates
   - Check certificate expiration
   - Verify certificate format

### Useful Commands

```bash
# Check pod logs
kubectl logs -n xroad <pod-name>

# Describe pod for events
kubectl describe pod -n xroad <pod-name>

# Check service endpoints
kubectl get endpoints -n xroad

# Check persistent volumes
kubectl get pv

# Check node resources
kubectl top nodes
```

## Security Considerations

1. **Secrets**: Update default passwords in secrets.yaml
2. **Certificates**: Replace placeholder certificates with real ones
3. **Network Policies**: Review and adjust network policies as needed
4. **RBAC**: Consider implementing role-based access control
5. **Pod Security**: Review security contexts and capabilities

## Monitoring

The deployment includes:
- Prometheus metrics collection
- Grafana dashboards
- Fluentd log aggregation
- Health checks and probes

Access monitoring through:
- Grafana: http://grafana.xroad.local
- Prometheus: http://prometheus.xroad.local
- Kibana: http://kibana.xroad.local (if Elasticsearch is deployed)
