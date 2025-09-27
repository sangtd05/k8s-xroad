# Cấu trúc thư mục X-Road Docker (Tối ưu)

## 📁 Cấu trúc thư mục sau khi tối ưu

```
k8s-xroad/
├── README.md                    # Tài liệu chính (gộp BUILD.md, QUICKSTART.md)
├── STRUCTURE.md                 # Cấu trúc thư mục này
├── config.env                   # Cấu hình môi trường (thay thế env.example)
├── docker-compose.yml           # Docker Compose chính
├── Makefile                     # Quản lý lệnh
├── .gitignore                   # Git ignore rules
│
├── Docker/                      # Docker images source
│   ├── centralserver/
│   │   ├── Dockerfile
│   │   └── files/
│   ├── securityserver/
│   │   ├── Dockerfile
│   │   └── files/
│   ├── testca/
│   │   ├── Dockerfile
│   │   └── files/
│   └── test-services/
│       └── example-adapter/
│           └── Dockerfile
│
├── nginx/                       # Nginx configuration
│   ├── nginx.conf
│   └── ssl/                     # SSL certificates
│
├── scripts/                     # Management scripts (tối ưu)
│   ├── start.sh                 # Khởi động (gộp restart.sh, generate-ssl.sh, init-system.sh)
│   ├── stop.sh                  # Dừng hệ thống
│   ├── status.sh                # Kiểm tra trạng thái
│   ├── backup.sh                # Backup/Restore
│   ├── build-images.sh          # Build Docker images
│   └── setup-remote-ss.sh       # Cấu hình Security Server từ xa
│
└── wiremock_mappings/           # Wiremock test data
    ├── is_rest_1.json
    ├── is_rest_2.json
    └── is_rest_3.json
```

## 🔄 Những thay đổi đã thực hiện

### ✅ Gộp file
- **README.md**: Gộp BUILD.md, QUICKSTART.md
- **start.sh**: Gộp restart.sh, generate-ssl.sh, init-system.sh
- **config.env**: Thay thế env.example với tên rõ ràng hơn

### ✅ Xóa file thừa
- **BUILD.md**: Nội dung đã gộp vào README.md
- **QUICKSTART.md**: Nội dung đã gộp vào README.md
- **env.example**: Thay thế bằng config.env
- **restart.sh**: Chức năng đã gộp vào start.sh
- **generate-ssl.sh**: Chức năng đã gộp vào start.sh
- **init-system.sh**: Chức năng đã gộp vào start.sh
- **Docker/xrd-dev-stack/**: Thư mục không sử dụng
- **Docker/test-services/payloadgen/**: Không sử dụng

### ✅ Tối ưu scripts
- **start.sh** bây giờ hỗ trợ:
  - `./scripts/start.sh` - Khởi động cơ bản
  - `./scripts/start.sh --init` - Khởi động và khởi tạo
  - `./scripts/start.sh --ssl` - Tạo SSL mới
  - `./scripts/start.sh --restart` - Khởi động lại
  - `./scripts/start.sh --restart-init` - Khởi động lại và khởi tạo
  - `./scripts/start.sh --restart-clean` - Khởi động lại với dọn dẹp

## 🚀 Cách sử dụng sau khi tối ưu

### Cài đặt nhanh
```bash
# Cài đặt hoàn chỉnh
make install

# Hoặc thủ công
cp config.env .env
make build
make start-init
```

### Quản lý hệ thống
```bash
# Khởi động
make start

# Dừng
make stop

# Khởi động lại
make restart

# Kiểm tra trạng thái
make status

# Xem logs
make logs
```

### Build images
```bash
# Build tất cả images
make build

# Build thủ công
./scripts/build-images.sh
```

## 📊 Thống kê tối ưu

### Trước khi tối ưu:
- **File scripts**: 9 files
- **File documentation**: 4 files (README.md, BUILD.md, QUICKSTART.md, STRUCTURE.md)
- **File config**: 2 files (env.example, config.env)
- **Tổng cộng**: ~15 files

### Sau khi tối ưu:
- **File scripts**: 6 files (-3 files)
- **File documentation**: 2 files (README.md, STRUCTURE.md) (-2 files)
- **File config**: 1 file (config.env) (-1 file)
- **Tổng cộng**: ~9 files (-6 files, giảm 40%)

## ✨ Lợi ích của cấu trúc mới

1. **Gọn gàng hơn**: Ít file hơn, dễ quản lý
2. **Tập trung chức năng**: Một script làm nhiều việc
3. **Dễ sử dụng**: Makefile với các lệnh rõ ràng
4. **Tài liệu đầy đủ**: Tất cả trong README.md
5. **Cấu hình rõ ràng**: config.env thay vì env.example
6. **Dễ mở rộng**: Cấu trúc có thể thêm tính năng mới

## 🔧 Maintenance

- **Thêm script mới**: Tạo file riêng trong `scripts/`
- **Cập nhật cấu hình**: Chỉnh sửa `config.env`
- **Cập nhật tài liệu**: Chỉnh sửa `README.md`
- **Thêm Docker image**: Tạo thư mục trong `Docker/`
