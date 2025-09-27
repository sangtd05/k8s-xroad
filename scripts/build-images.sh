#!/bin/bash

# Script build Docker images từ thư mục Docker
# Usage: ./scripts/build-images.sh

set -e

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hàm in thông báo
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Hàm build image
build_image() {
    local dockerfile_path=$1
    local image_name=$2
    local build_args=$3
    
    print_info "Building $image_name from $dockerfile_path..."
    
    if [ -f "$dockerfile_path" ]; then
        docker build $build_args -t "$image_name" -f "$dockerfile_path" .
        print_success "$image_name built successfully"
    else
        print_error "Dockerfile not found: $dockerfile_path"
        return 1
    fi
}

# Main function
main() {
    print_info "Building X-Road Docker images from local Dockerfiles..."
    echo ""
    
    # Kiểm tra thư mục Docker
    if [ ! -d "Docker" ]; then
        print_error "Thư mục Docker không tồn tại"
        exit 1
    fi
    
    # Build Central Server
    print_info "Building Central Server..."
    build_image "Docker/centralserver/Dockerfile" "xroad-centralserver:latest" "--build-arg PACKAGE_SOURCE=external"
    echo ""
    
    # Build Security Server
    print_info "Building Security Server..."
    build_image "Docker/securityserver/Dockerfile" "xroad-securityserver:latest" "--build-arg PACKAGE_SOURCE=external"
    echo ""
    
    # Build Test CA (using simple version)
    print_info "Building Test CA (simple version)..."
    if [ -f "Docker/testca/Dockerfile.simple" ]; then
        build_image "Docker/testca/Dockerfile.simple" "xroad-testca:latest"
    else
        build_image "Docker/testca/Dockerfile" "xroad-testca:latest"
    fi
    echo ""
    
    # Build Example Adapter (SOAP)
    print_info "Building Example Adapter (SOAP)..."
    build_image "Docker/test-services/example-adapter/Dockerfile" "xroad-example-adapter:latest"
    echo ""
    
    # Build Example REST API (nếu có)
    if [ -f "Docker/test-services/example-restapi/Dockerfile" ]; then
        print_info "Building Example REST API..."
        build_image "Docker/test-services/example-restapi/Dockerfile" "xroad-example-restapi:latest"
        echo ""
    else
        print_warning "Example REST API Dockerfile not found, using external image"
    fi
    
    # Kiểm tra images đã build
    print_info "Checking built images..."
    docker images | grep xroad
    echo ""
    
    print_success "All X-Road images built successfully!"
    print_info "Images available:"
    echo "  • xroad-centralserver:latest"
    echo "  • xroad-securityserver:latest"
    echo "  • xroad-testca:latest"
    echo "  • xroad-example-adapter:latest"
    echo "  • xroad-example-restapi:latest (if available)"
    echo ""
    print_info "You can now start the system with: make start"
}

# Chạy main function
main "$@"
