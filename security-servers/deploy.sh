#!/bin/bash
set -euo pipefail

echo "=== X-Road Security Servers Deployment ==="
echo "This script will deploy Security Servers on Kubernetes"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is required but not installed. Please install kubectl first."
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

echo "Step 1: Creating namespace..."
kubectl apply -f 00-namespace.yaml

echo ""
echo "Step 2: Setting up MetalLB (if needed)..."
if ! kubectl get crd addresspools.metallb.io &> /dev/null; then
    echo "MetalLB not found. Please install MetalLB first:"
    echo "kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml"
    exit 1
fi

kubectl apply -f 01-metallb/10-address-pool.yaml
kubectl apply -f 01-metallb/20-l2advertisement.yaml

echo ""
echo "Step 3: Creating secrets..."
if [ ! -f "secrets/10-xroad-secrets.yaml" ]; then
    echo "Creating secrets from template..."
    ./99-helpers/create-secrets.sh
fi

kubectl apply -f 10-secrets/10-xroad-secrets.yaml
kubectl apply -f 10-secrets/20-xroad-db-properties.yaml

echo ""
echo "Step 4: Setting up storage..."
kubectl apply -f 20-storage/10-pvc-primary.yaml
kubectl apply -f 20-storage/20-pvc-secondary.yaml

echo ""
echo "Step 5: Deploying PostgreSQL cluster..."
# Check if Zalando Postgres Operator is installed
if ! kubectl get crd postgresqls.acid.zalan.do &> /dev/null; then
    echo "Zalando Postgres Operator not found. Please install it first:"
    echo "kubectl apply -f https://raw.githubusercontent.com/zalando/postgres-operator/v1.10.0/manifests/postgres-operator.yaml"
    exit 1
fi

kubectl apply -f 30-db/10-postgres-cluster.yaml
kubectl apply -f 30-db/20-networkpolicy-db.yaml

echo ""
echo "Step 6: Waiting for PostgreSQL to be ready..."
kubectl -n xroad wait --for=condition=Ready postgresql/xroad-pg --timeout=300s

echo ""
echo "Step 7: Deploying Security Servers..."
kubectl apply -f 40-ss/10-primary.yaml
kubectl apply -f 40-ss/20-secondary.yaml
kubectl apply -f 40-ss/30-networkpolicies.yaml

echo ""
echo "Step 8: Waiting for Security Servers to be ready..."
kubectl -n xroad wait --for=condition=Available deployment/ss-primary --timeout=300s
kubectl -n xroad wait --for=condition=Available deployment/ss-secondary --timeout=300s

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Security Servers Status:"
kubectl -n xroad get pods -o wide
echo ""
echo "Services:"
kubectl -n xroad get svc
echo ""
echo "Next steps:"
echo "1. Get external IP: kubectl -n xroad get svc ss-public"
echo "2. Port-forward to Primary: kubectl -n xroad port-forward deploy/ss-primary 4000:4000"
echo "3. Access Primary UI: https://127.0.0.1:4000/"
echo "4. Import configuration anchor from Central Server"
echo "5. Register Security Server with Central Server"
