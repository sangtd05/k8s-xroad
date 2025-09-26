#!/bin/bash
set -euo pipefail

echo "�� Cleaning up X-Road deployment..."

# Xóa deployments
kubectl delete deployment --all -n xroad
kubectl delete deployment --all -n xroad-monitoring

# Xóa services
kubectl delete service --all -n xroad
kubectl delete service --all -n xroad-monitoring

# Xóa PVCs
kubectl delete pvc --all -n xroad

# Xóa PVs
kubectl delete pv --all

# Xóa namespaces
kubectl delete namespace xroad
kubectl delete namespace xroad-monitoring

echo "✅ Cleanup completed!"