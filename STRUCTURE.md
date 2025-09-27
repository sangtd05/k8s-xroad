# X-Road Helm Project Structure

## 📁 Optimized Project Structure

```
x-road-helm/
├── xroad.sh                    # 🚀 Main entry point script
├── values.yaml                 # ⚙️ Default configuration
├── README.md                   # 📖 Main documentation
├── LICENSE                     # 📄 License file
├── STRUCTURE.md               # 📋 This file
│
├── helm/                      # 📦 Helm charts
│   └── xroad/                 # Main X-Road chart
│       ├── Chart.yaml         # Chart metadata
│       ├── values.yaml        # Chart default values
│       └── templates/         # Kubernetes templates
│           ├── _helpers.tpl
│           ├── central-server.yaml
│           ├── security-server.yaml
│           ├── postgresql.yaml
│           └── NOTES.txt
│
├── scripts/                   # 🔧 Management scripts
│   ├── deploy-3worker.sh      # Deployment script
│   ├── cleanup.sh             # Full cleanup
│   ├── quick-cleanup.sh       # Quick cleanup
│   ├── status-check.sh        # Status checker
│   └── manage.sh              # Advanced management
│
├── docs/                      # 📚 Documentation
│   └── 3WORKER_DEPLOYMENT.md  # Detailed deployment guide
│
├── examples/                  # 📝 Example configurations
│   ├── xroad-3worker-values.yaml  # 3-worker node config
│   └── docker-compose.yml     # Local testing
│
└── docker/                    # 🐳 Docker configurations
    └── central-server/        # Central Server Docker files
        ├── Dockerfile
        └── files/
```

## 🎯 Key Improvements

### 1. **Simplified Entry Point**
- Single `xroad.sh` script for all operations
- Clear command structure: `./xroad.sh <command>`
- Automatic script discovery and execution

### 2. **Organized Directories**
- `scripts/` - All management scripts
- `docs/` - Documentation files
- `examples/` - Example configurations
- `helm/` - Only the main chart (removed duplicates)

### 3. **Removed Redundancy**
- ❌ Deleted duplicate charts (`central-server`, `security-server`, `pgop`)
- ❌ Removed old example files
- ❌ Consolidated documentation
- ❌ Removed temporary files

### 4. **Streamlined Configuration**
- `values.yaml` - Main configuration file
- `examples/xroad-3worker-values.yaml` - 3-worker specific config
- Automatic fallback to default values

## 🚀 Usage

### Quick Start
```bash
# Deploy X-Road
./xroad.sh deploy

# Check status
./xroad.sh status

# View logs
./xroad.sh logs all
```

### Advanced Operations
```bash
# Scale Security Server
./xroad.sh scale 3

# Create backup
./xroad.sh backup

# Cleanup
./xroad.sh cleanup
```

## 📋 File Descriptions

### Main Files
- **`xroad.sh`** - Main entry point, routes to appropriate scripts
- **`values.yaml`** - Default configuration for all deployments
- **`README.md`** - Main documentation and quick start guide

### Scripts Directory
- **`deploy-3worker.sh`** - Deploys X-Road on 3-worker cluster
- **`cleanup.sh`** - Full cleanup with confirmation
- **`quick-cleanup.sh`** - Quick cleanup without confirmation
- **`status-check.sh`** - Comprehensive status checking
- **`manage.sh`** - Advanced management operations

### Documentation
- **`docs/3WORKER_DEPLOYMENT.md`** - Detailed deployment guide
- **`STRUCTURE.md`** - This file explaining project structure

### Examples
- **`examples/xroad-3worker-values.yaml`** - 3-worker node configuration
- **`examples/docker-compose.yml`** - Local testing setup

## 🔧 Configuration Hierarchy

1. **Default**: `values.yaml` (always used)
2. **Custom**: `examples/xroad-3worker-values.yaml` (if exists)
3. **Override**: Command line `--values` parameter

## 🎨 Design Principles

### 1. **Simplicity**
- Single entry point
- Clear command structure
- Minimal file count

### 2. **Organization**
- Logical directory structure
- Related files grouped together
- Clear naming conventions

### 3. **Maintainability**
- Easy to find files
- Clear separation of concerns
- Minimal redundancy

### 4. **Usability**
- Intuitive commands
- Good documentation
- Helpful error messages

## 🔄 Migration from Old Structure

### What Changed
- Moved all scripts to `scripts/` directory
- Consolidated documentation to `docs/`
- Moved examples to `examples/`
- Removed duplicate charts
- Created single entry point

### What Stayed the Same
- Core functionality
- Helm chart structure
- Configuration options
- Deployment process

## 📈 Benefits

1. **Easier to Use**: Single `xroad.sh` command
2. **Better Organized**: Clear directory structure
3. **Less Confusing**: Removed duplicate files
4. **More Maintainable**: Logical file organization
5. **Cleaner Repository**: Minimal file count

## 🚀 Next Steps

1. Test the new structure
2. Update any external references
3. Add new features as needed
4. Keep documentation updated

This optimized structure provides a clean, maintainable, and user-friendly X-Road deployment solution.
