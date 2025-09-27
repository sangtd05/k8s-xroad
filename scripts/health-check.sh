#!/bin/bash
set -euo pipefail

echo "=== X-Road Health Check ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a service is running
check_service() {
    local service_name=$1
    if systemctl is-active --quiet "$service_name"; then
        print_status "$service_name is running"
        return 0
    else
        print_error "$service_name is not running"
        return 1
    fi
}

# Function to check if a port is listening
check_port() {
    local port=$1
    local service_name=$2
    if ss -tlpn | grep -q ":$port "; then
        print_status "$service_name is listening on port $port"
        return 0
    else
        print_error "$service_name is not listening on port $port"
        return 1
    fi
}

# Function to check if a URL is accessible
check_url() {
    local url=$1
    local service_name=$2
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|400"; then
        print_status "$service_name is accessible at $url"
        return 0
    else
        print_error "$service_name is not accessible at $url"
        return 1
    fi
}

# Function to check Kubernetes resources
check_k8s_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    if kubectl get "$resource_type" "$resource_name" -n "$namespace" &>/dev/null; then
        print_status "$resource_type $resource_name exists in namespace $namespace"
        return 0
    else
        print_error "$resource_type $resource_name not found in namespace $namespace"
        return 1
    fi
}

echo "=== Central Server Health Check ==="
echo ""

# Check Central Server services
check_service "xroad-center"
check_service "xroad-center-registration-service"
check_service "xroad-center-management-service"
check_service "xroad-signer"
check_service "xroad-nginx"

echo ""
echo "=== Central Server Ports ==="
echo ""

# Check Central Server ports
check_port "80" "HTTP"
check_port "443" "HTTPS"
check_port "4000" "Central Server UI"
check_port "5500" "X-Road Message Protocol"
check_port "5577" "X-Road Management Protocol"

echo ""
echo "=== Central Server URLs ==="
echo ""

# Check Central Server URLs
check_url "https://127.0.0.1:4000/" "Central Server UI"
check_url "http://127.0.0.1:5588/" "Master Security Server Health"

echo ""
echo "=== Master Security Server ==="
echo ""

# Check Docker container
if command_exists docker; then
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "xroad-ss-mgmt"; then
        print_status "Master Security Server container is running"
    else
        print_error "Master Security Server container is not running"
    fi
else
    print_warning "Docker is not installed"
fi

echo ""
echo "=== PKI Services Health Check ==="
echo ""

# Check PKI Services ports
check_port "8888" "OCSP Responder"
check_port "3000" "TSA Server"

echo ""
echo "=== PKI Services URLs ==="
echo ""

# Check PKI Services URLs
check_url "http://127.0.0.1:8888" "OCSP Responder"
check_url "http://127.0.0.1:3000/api/v1/timestamp/certchain" "TSA Server"

echo ""
echo "=== Kubernetes Cluster Health Check ==="
echo ""

# Check if kubectl can connect
if kubectl cluster-info &>/dev/null; then
    print_status "Kubernetes cluster is accessible"
    
    # Check Security Servers namespace
    if kubectl get namespace xroad &>/dev/null; then
        print_status "X-Road namespace exists"
        
        echo ""
        echo "=== Security Servers Pods ==="
        echo ""
        
        # Check Security Server pods
        check_k8s_resource "deployment" "ss-primary" "xroad"
        check_k8s_resource "deployment" "ss-secondary" "xroad"
        
        echo ""
        echo "=== Security Servers Services ==="
        echo ""
        
        # Check Security Server services
        check_k8s_resource "service" "ss-primary" "xroad"
        check_k8s_resource "service" "ss-secondary" "xroad"
        check_k8s_resource "service" "ss-public" "xroad"
        
        echo ""
        echo "=== PostgreSQL Cluster ==="
        echo ""
        
        # Check PostgreSQL cluster
        check_k8s_resource "postgresql" "xroad-pg" "xroad"
        
        echo ""
        echo "=== Pod Status ==="
        echo ""
        
        # Show pod status
        kubectl -n xroad get pods -o wide
        
        echo ""
        echo "=== Service Status ==="
        echo ""
        
        # Show service status
        kubectl -n xroad get svc
        
    else
        print_error "X-Road namespace not found. Security Servers may not be deployed."
    fi
else
    print_error "Cannot connect to Kubernetes cluster"
fi

echo ""
echo "=== System Resources ==="
echo ""

# Check system resources
echo "Memory usage:"
free -h

echo ""
echo "Disk usage:"
df -h

echo ""
echo "=== Network Connectivity ==="
echo ""

# Check network connectivity
if ping -c 1 8.8.8.8 &>/dev/null; then
    print_status "Internet connectivity is working"
else
    print_warning "Internet connectivity issues detected"
fi

echo ""
echo "=== Health Check Complete ==="
echo ""

# Summary
echo "Summary:"
echo "- Central Server: Check services and ports above"
echo "- PKI Services: Check OCSP and TSA services above"
echo "- Security Servers: Check Kubernetes resources above"
echo ""
echo "For detailed troubleshooting, check the documentation in docs/ directory"
