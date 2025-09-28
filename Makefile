# X-Road Docker Deployment Makefile
# Sử dụng: make <target>

.PHONY: help start stop restart status logs clean backup restore init ssl setup-remote

# Default target
help: ## Hiển thị danh sách các lệnh có sẵn
	@echo "X-Road Docker Deployment Commands:"
	@echo "=================================="
	@echo ""
	@echo "🚀 Khởi động hệ thống:"
	@echo "  start          Khởi động hệ thống X-Road"
	@echo "  start-init     Khởi động và khởi tạo hệ thống"
	@echo "  start-ssl      Khởi động với SSL certificate mới"
	@echo ""
	@echo "🛑 Dừng hệ thống:"
	@echo "  stop           Dừng hệ thống"
	@echo "  stop-clean     Dừng và dọn dẹp hoàn toàn"
	@echo ""
	@echo "🔄 Quản lý hệ thống:"
	@echo "  restart        Khởi động lại hệ thống"
	@echo "  restart-clean  Khởi động lại với dọn dẹp"
	@echo "  restart-init   Khởi động lại và khởi tạo"
	@echo ""
	@echo "📊 Kiểm tra trạng thái:"
	@echo "  status         Kiểm tra trạng thái hệ thống"
	@echo "  status-detailed Kiểm tra trạng thái chi tiết"
	@echo "  logs           Xem logs hệ thống"
	@echo "  logs-service   Xem logs của service cụ thể"
	@echo ""
	@echo "🔧 Cấu hình:"
	@echo "  init           Khởi tạo hệ thống"
	@echo "  ssl            Tạo SSL certificate"
	@echo "  setup-remote   Cấu hình Security Server từ xa"
	@echo ""
	@echo "💾 Backup & Restore:"
	@echo "  backup         Tạo backup hệ thống"
	@echo "  backup-list    Liệt kê các backup"
	@echo "  restore        Restore backup (cần chỉ định BACKUP_NAME)"
	@echo ""
	@echo "🧹 Dọn dẹp:"
	@echo "  clean          Dọn dẹp hệ thống"
	@echo "  clean-all      Dọn dẹp hoàn toàn (cả images)"
	@echo ""
	@echo "📚 Ví dụ sử dụng:"
	@echo "  make start-init"
	@echo "  make status-detailed"
	@echo "  make logs-service SERVICE=centralserver"
	@echo "  make restore BACKUP_NAME=xroad-backup-20241228-120000"

# Khởi động hệ thống
start: ## Khởi động hệ thống X-Road
	@echo "🚀 Khởi động hệ thống X-Road..."
	@./scripts/start.sh

start-init: ## Khởi động và khởi tạo hệ thống
	@echo "🚀 Khởi động và khởi tạo hệ thống X-Road..."
	@./scripts/start.sh --init

start-ssl: ## Khởi động với SSL certificate mới
	@echo "🚀 Khởi động với SSL certificate mới..."
	@./scripts/start.sh --ssl

# Dừng hệ thống
stop: ## Dừng hệ thống
	@echo "🛑 Dừng hệ thống X-Road..."
	@./scripts/stop.sh

stop-clean: ## Dừng và dọn dẹp hoàn toàn
	@echo "🛑 Dừng và dọn dẹp hệ thống X-Road..."
	@./scripts/stop.sh --clean

# Khởi động lại hệ thống
restart: ## Khởi động lại hệ thống
	@echo "🔄 Khởi động lại hệ thống X-Road..."
	@./scripts/start.sh --restart

restart-clean: ## Khởi động lại với dọn dẹp
	@echo "🔄 Khởi động lại với dọn dẹp hệ thống X-Road..."
	@./scripts/start.sh --restart-clean

restart-init: ## Khởi động lại và khởi tạo
	@echo "🔄 Khởi động lại và khởi tạo hệ thống X-Road..."
	@./scripts/start.sh --restart-init

# Kiểm tra trạng thái
status: ## Kiểm tra trạng thái hệ thống
	@echo "📊 Kiểm tra trạng thái hệ thống X-Road..."
	@./scripts/status.sh

status-detailed: ## Kiểm tra trạng thái chi tiết
	@echo "📊 Kiểm tra trạng thái chi tiết hệ thống X-Road..."
	@./scripts/status.sh --detailed

logs: ## Xem logs hệ thống
	@echo "📋 Xem logs hệ thống X-Road..."
	@./scripts/status.sh --logs

logs-service: ## Xem logs của service cụ thể (SERVICE=service_name)
	@echo "📋 Xem logs của service $(SERVICE)..."
	@./scripts/status.sh --logs --service $(SERVICE)

# Cấu hình
init: ## Khởi tạo hệ thống
	@echo "🔧 Khởi tạo hệ thống X-Road..."
	@./scripts/start.sh --init

ssl: ## Tạo SSL certificate
	@echo "🔐 Tạo SSL certificate..."
	@./scripts/start.sh --ssl

setup-remote: ## Cấu hình Security Server từ xa
	@echo "🌐 Cấu hình Security Server từ xa..."
	@./scripts/setup-remote-ss.sh

# Backup & Restore
backup: ## Tạo backup hệ thống
	@echo "💾 Tạo backup hệ thống X-Road..."
	@./scripts/backup.sh

backup-list: ## Liệt kê các backup
	@echo "📋 Liệt kê các backup..."
	@./scripts/backup.sh --list

restore: ## Restore backup (cần chỉ định BACKUP_NAME)
	@echo "🔄 Restore backup $(BACKUP_NAME)..."
	@./scripts/backup.sh --restore $(BACKUP_NAME)

# Dọn dẹp
clean: ## Dọn dẹp hệ thống
	@echo "🧹 Dọn dẹp hệ thống X-Road..."
	@if command -v docker-compose &> /dev/null; then docker-compose down -v --remove-orphans; else docker compose down -v --remove-orphans; fi
	@docker system prune -f

clean-all: ## Dọn dẹp hoàn toàn (cả images)
	@echo "🧹 Dọn dẹp hoàn toàn hệ thống X-Road..."
	@if command -v docker-compose &> /dev/null; then docker-compose down -v --remove-orphans; else docker compose down -v --remove-orphans; fi
	@docker system prune -a -f
	@docker volume prune -f

# Cài đặt
install: ## Cài đặt hệ thống (tạo .env, build images, SSL, khởi động)
	@echo "⚙️ Cài đặt hệ thống X-Road..."
	@cp config.env .env
	@make build
	@make ssl
	@make start-init

build: ## Build Docker images từ thư mục Docker
	@echo "🔨 Building Docker images..."
	@./scripts/build-images.sh

# Kiểm tra
check: ## Kiểm tra cấu hình và prerequisites
	@echo "✅ Kiểm tra cấu hình và prerequisites..."
	@docker --version
	@if command -v docker-compose &> /dev/null; then docker-compose --version; else docker compose version; fi
	@if [ ! -f ".env" ]; then echo "❌ File .env không tồn tại"; exit 1; fi
	@if [ ! -f "docker-compose.yml" ]; then echo "❌ File docker-compose.yml không tồn tại"; exit 1; fi
	@echo "✅ Tất cả prerequisites đã sẵn sàng"

# Cập nhật
update: ## Cập nhật images và khởi động lại
	@echo "🔄 Cập nhật images và khởi động lại..."
	@echo "⚠️  Lưu ý: Hệ thống sử dụng images local, không pull từ registry"
	@make restart

# Test
test: ## Chạy test kết nối
	@echo "🧪 Chạy test kết nối..."
	@curl -s -f -k https://localhost:4000 > /dev/null && echo "✅ Central Server: OK" || echo "❌ Central Server: FAILED"
	@curl -s -f -k https://localhost:4001 > /dev/null && echo "✅ Security Server: OK" || echo "❌ Security Server: FAILED"
	@curl -s -f -k http://localhost:8888/testca/certs > /dev/null && echo "✅ Test CA: OK" || echo "❌ Test CA: FAILED"

# Hiển thị thông tin
info: ## Hiển thị thông tin hệ thống
	@echo "ℹ️ Thông tin hệ thống X-Road:"
	@echo "=============================="
	@echo "🌐 Web Interfaces:"
	@echo "  • Central Server:     https://localhost:4000"
	@echo "  • Security Server:    https://localhost:4001"
	@echo "  • Test CA:            https://localhost:8888"
	@echo "  • Mailpit:            https://localhost:8025"
	@echo ""
	@echo "🔌 API Endpoints:"
	@echo "  • REST API:           http://localhost:8082"
	@echo "  • SOAP API:           http://localhost:8083"
	@echo "  • OpenAPI:            http://localhost:8084"
	@echo ""
	@echo "🔐 Default Credentials:"
	@echo "  • Username: xrd"
	@echo "  • Password: secret"
	@echo ""
	@echo "📝 Useful Commands:"
	@echo "  • View logs:          make logs"
	@echo "  • Check status:       make status"
	@echo "  • Stop system:        make stop"
	@echo "  • Restart system:     make restart"
