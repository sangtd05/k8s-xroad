#!/bin/bash
set -euo pipefail

echo "�� Setting up X-Road Kubernetes deployment structure..."

# Tạo cấu trúc thư mục
mkdir -p {namespaces,storage,postgresql,central-server,security-server,monitoring,configmaps,secrets,scripts}

# Tạo file README
cat > README.md << 'EOF'
# X-Road Kubernetes Deployment

This directory contains all the necessary files to deploy X-Road on Kubernetes with 3 worker nodes.

## Prerequisites

- Kubernetes cluster with 1 master and 3 worker nodes
- kubectl configured to access the cluster
- At least 4 CPU cores and 8GB RAM per worker node
- 50GB storage per worker node

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
EOF

# Tạo file .gitignore
cat > .gitignore << 'EOF'
# Kubernetes
*.log
*.tmp
.DS_Store

# Sensitive data
secrets/secret.yaml
configmaps/configmap.yaml
EOF

echo "✅ Directory structure created successfully!"
echo "📁 Created directories:"
ls -la
echo ""
echo "🚀 Next steps:"
echo "1. Review and customize the YAML files"
echo "2. Run: chmod +x scripts/*.sh"
echo "3. Run: ./scripts/deploy.sh"