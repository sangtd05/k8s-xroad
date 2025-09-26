#!/bin/bash
set -euo pipefail

echo "�� Starting X-Road deployment on Kubernetes..."

# Kiểm tra kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Kiểm tra kết nối cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Kubernetes cluster connection verified"

# Tạo namespace
echo "📁 Creating namespaces..."
kubectl apply -f ../namespaces/namespace.yaml

# Tạo storage class và persistent volumes
echo "💾 Setting up storage..."
kubectl apply -f ../storage/storage-class.yaml
kubectl apply -f ../storage/persistent-volumes.yaml

# Triển khai PostgreSQL
echo "�� Deploying PostgreSQL..."
kubectl apply -f ../postgresql/postgresql.yaml

# Chờ PostgreSQL sẵn sàng
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n xroad --timeout=300s

# Triển khai Central Server
echo "🏢 Deploying Central Server..."
kubectl apply -f ../central-server/central-server.yaml

# Chờ Central Server sẵn sàng
echo "⏳ Waiting for Central Server to be ready..."
kubectl wait --for=condition=ready pod -l app=central-server -n xroad --timeout=300s

# Triển khai Security Server Sidecar
echo "🔒 Deploying Security Server Sidecar..."
kubectl apply -f ../security-server/security-server-sidecar.yaml

# Chờ Security Server sẵn sàng
echo "⏳ Waiting for Security Server Sidecar to be ready..."
kubectl wait --for=condition=ready pod -l app=security-server-sidecar -n xroad --timeout=300s

# Triển khai Monitoring
echo "�� Deploying Monitoring..."
kubectl apply -f ../monitoring/prometheus.yaml
kubectl apply -f ../monitoring/grafana.yaml

echo "✅ X-Road deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "======================"
kubectl get pods -n xroad
echo ""
kubectl get svc -n xroad
echo ""
kubectl get pv
echo ""
echo "🔍 To check logs:"
echo "kubectl logs -f deployment/security-server-sidecar -n xroad"
echo ""
echo "🌐 To access services:"
echo "kubectl get svc -n xroad"