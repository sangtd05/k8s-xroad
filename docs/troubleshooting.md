# Troubleshooting Guide

Hướng dẫn khắc phục sự cố cho hệ thống X-Road.

## Tổng quan

Tài liệu này cung cấp các bước khắc phục sự cố phổ biến cho:
- Central Server
- PKI Services
- Security Servers trên Kubernetes

## Central Server Issues

### Central Server không khởi động

#### Triệu chứng
- Service `xroad-center` không start
- Logs hiển thị lỗi cấu hình
- Port 4000 không accessible

#### Khắc phục
```bash
# Kiểm tra logs
sudo journalctl -u xroad-center -n 50

# Kiểm tra cấu hình
sudo xroad-center --check-config

# Kiểm tra permissions
sudo ls -la /etc/xroad/
sudo chown -R xroad:xroad /etc/xroad/

# Restart service
sudo systemctl restart xroad-center
```

#### Nguyên nhân thường gặp
- Cấu hình file không đúng
- Permissions không đúng
- Database connection issues
- Port conflicts

### Master Security Server không kết nối

#### Triệu chứng
- Container `xroad-ss-mgmt` không start
- Logs hiển thị connection errors
- UI không accessible

#### Khắc phục
```bash
# Kiểm tra container logs
docker logs xroad-ss-mgmt

# Kiểm tra container status
docker ps -a

# Kiểm tra network
docker network ls
docker inspect xroad-ss-mgmt

# Restart container
docker restart xroad-ss-mgmt

# Recreate container
docker-compose -f compose/docker-compose.yml down
docker-compose -f compose/docker-compose.yml up -d
```

#### Nguyên nhân thường gặp
- Central Server chưa sẵn sàng
- Network configuration issues
- Resource constraints
- Configuration errors

### Database connection issues

#### Triệu chứng
- Central Server không thể kết nối database
- Logs hiển thị database errors
- Services không start

#### Khắc phục
```bash
# Kiểm tra PostgreSQL status
sudo systemctl status postgresql

# Kiểm tra database connectivity
sudo -u postgres psql -c "SELECT version();"

# Kiểm tra database exists
sudo -u postgres psql -c "\l"

# Kiểm tra user permissions
sudo -u postgres psql -c "\du"

# Restart PostgreSQL
sudo systemctl restart postgresql
```

#### Nguyên nhân thường gặp
- PostgreSQL không chạy
- Database không tồn tại
- User permissions không đúng
- Connection limits

## PKI Services Issues

### OCSP Responder không hoạt động

#### Triệu chứng
- Port 8888 không accessible
- OCSP requests fail
- Logs hiển thị errors

#### Khắc phục
```bash
# Kiểm tra process
ps aux | grep ocsp

# Kiểm tra port
ss -tlpn | grep 8888

# Test OCSP locally
openssl ocsp -port 8888 -index pki/intermediate/index.txt \
  -CA pki/ca-chain.crt -rkey pki/private/ocsp.key.pem \
  -rsigner pki/ocsp.crt -text

# Restart OCSP
sudo pkill -f ocsp
sudo ./scripts/start-ocsp.sh &
```

#### Nguyên nhân thường gặp
- Port conflicts
- Certificate issues
- Configuration errors
- Process crashes

### TSA Server không hoạt động

#### Triệu chứng
- Port 3000 không accessible
- TSA requests fail
- Python errors

#### Khắc phục
```bash
# Kiểm tra process
ps aux | grep tsa_server

# Kiểm tra port
ss -tlpn | grep 3000

# Kiểm tra Python environment
cd pki-services
source .venv/bin/activate
python app/tsa_server.py

# Test TSA API
curl -I http://127.0.0.1:3000/api/v1/timestamp/certchain

# Restart TSA
pkill -f tsa_server
./scripts/start-tsa.sh &
```

#### Nguyên nhân thường gặp
- Python dependencies missing
- Port conflicts
- Certificate issues
- Configuration errors

### Certificate issues

#### Triệu chứng
- Certificates không valid
- Chain verification fails
- OCSP/TSA không hoạt động

#### Khắc phục
```bash
# Kiểm tra certificate validity
openssl x509 -in pki/tsa.crt -text -noout

# Kiểm tra certificate chain
openssl verify -CAfile pki/ca-chain.crt pki/tsa.crt

# Regenerate certificates
sudo ./scripts/generate-pki.sh

# Kiểm tra OCSP certificate
openssl x509 -in pki/ocsp.crt -text -noout
```

#### Nguyên nhân thường gặp
- Certificates expired
- Chain broken
- Key mismatches
- Configuration errors

## Security Servers Issues

### Pod không khởi động

#### Triệu chứng
- Pods stuck in Pending/Error state
- Logs hiển thị errors
- Services không accessible

#### Khắc phục
```bash
# Kiểm tra pod status
kubectl -n xroad get pods

# Kiểm tra pod details
kubectl -n xroad describe pod <pod-name>

# Kiểm tra events
kubectl -n xroad get events --sort-by=.metadata.creationTimestamp

# Kiểm tra logs
kubectl -n xroad logs <pod-name> --previous

# Restart deployment
kubectl -n xroad rollout restart deployment/ss-primary
kubectl -n xroad rollout restart deployment/ss-secondary
```

#### Nguyên nhân thường gặp
- Resource constraints
- Image pull issues
- Configuration errors
- Storage issues

### Database connection issues

#### Triệu chứng
- Security Servers không kết nối database
- Logs hiển thị database errors
- Services không start

#### Khắc phục
```bash
# Kiểm tra PostgreSQL cluster
kubectl -n xroad get postgresql

# Kiểm tra PostgreSQL pods
kubectl -n xroad get pods -l application=spilo

# Kiểm tra database connectivity
kubectl -n xroad exec -it postgres-xroad-pg-0 -- psql -U xroad_app -d serverconf -c "SELECT 1;"

# Kiểm tra secrets
kubectl -n xroad get secret xroad-db-properties -o yaml

# Restart PostgreSQL
kubectl -n xroad delete pod postgres-xroad-pg-0
```

#### Nguyên nhân thường gặp
- PostgreSQL cluster không ready
- Database credentials không đúng
- Network connectivity issues
- Resource constraints

### Network connectivity issues

#### Triệu chứng
- Pods không thể communicate
- Services không accessible
- DNS resolution fails

#### Khắc phục
```bash
# Kiểm tra network policies
kubectl -n xroad get networkpolicies

# Kiểm tra service connectivity
kubectl -n xroad exec -it <pod-name> -- curl -k https://ss-primary:4000/

# Kiểm tra DNS resolution
kubectl -n xroad exec -it <pod-name> -- nslookup ss-primary

# Kiểm tra endpoints
kubectl -n xroad get endpoints

# Test port connectivity
kubectl -n xroad exec -it <pod-name> -- telnet ss-primary 4000
```

#### Nguyên nhân thường gặp
- Network policies blocking traffic
- DNS issues
- Service configuration errors
- Firewall rules

### Storage issues

#### Triệu chứng
- PVCs không bound
- Pods không start
- Storage errors

#### Khắc phục
```bash
# Kiểm tra PVCs
kubectl -n xroad get pvc

# Kiểm tra storage classes
kubectl get storageclass

# Kiểm tra PVs
kubectl get pv

# Kiểm tra pod events
kubectl -n xroad describe pod <pod-name>
```

#### Nguyên nhân thường gặp
- Storage class không available
- Insufficient storage
- Permission issues
- Configuration errors

## Performance Issues

### High CPU usage

#### Triệu chứng
- Pods sử dụng CPU cao
- Slow response times
- System overload

#### Khắc phục
```bash
# Kiểm tra resource usage
kubectl -n xroad top pods
kubectl -n xroad top nodes

# Kiểm tra resource limits
kubectl -n xroad describe pod <pod-name>

# Scale up resources
kubectl -n xroad patch deployment ss-primary -p '{"spec":{"template":{"spec":{"containers":[{"name":"sidecar","resources":{"requests":{"cpu":"2000m","memory":"6Gi"},"limits":{"cpu":"4000m","memory":"8Gi"}}}]}}}}'
```

### High memory usage

#### Triệu chứng
- Pods sử dụng memory cao
- OOMKilled errors
- Slow performance

#### Khắc phục
```bash
# Kiểm tra memory usage
kubectl -n xroad top pods
kubectl -n xroad describe pod <pod-name>

# Kiểm tra memory limits
kubectl -n xroad get pod <pod-name> -o jsonpath='{.spec.containers[0].resources}'

# Scale up memory
kubectl -n xroad patch deployment ss-primary -p '{"spec":{"template":{"spec":{"containers":[{"name":"sidecar","resources":{"requests":{"memory":"6Gi"},"limits":{"memory":"8Gi"}}}]}}}}'
```

### Database performance issues

#### Triệu chứng
- Slow database queries
- High database CPU usage
- Connection timeouts

#### Khắc phục
```bash
# Kiểm tra database performance
kubectl -n xroad exec -it postgres-xroad-pg-0 -- psql -U xroad_app -d serverconf

# Kiểm tra active connections
SELECT count(*) FROM pg_stat_activity;

# Kiểm tra slow queries
SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;

# Kiểm tra database size
SELECT pg_size_pretty(pg_database_size('serverconf'));
```

## Monitoring và Alerting

### Health Check Script

```bash
# Chạy health check tổng thể
./scripts/health-check.sh

# Health check cho từng component
cd central-server && ./scripts/health-check.sh
cd pki-services && ./scripts/health-check.sh
cd security-servers && kubectl -n xroad get pods
```

### Log Monitoring

```bash
# Central Server logs
sudo journalctl -u xroad-center -f

# Master Security Server logs
docker logs -f xroad-ss-mgmt

# Security Server logs
kubectl -n xroad logs -f deploy/ss-primary
kubectl -n xroad logs -f deploy/ss-secondary

# PostgreSQL logs
kubectl -n xroad logs -f postgres-xroad-pg-0
```

### Resource Monitoring

```bash
# System resources
htop
iostat -x 1
df -h

# Kubernetes resources
kubectl -n xroad top pods
kubectl -n xroad top nodes
kubectl -n xroad get events --sort-by=.metadata.creationTimestamp
```

## Backup và Recovery

### Backup

```bash
# Backup Central Server
sudo tar -czf central-server-backup-$(date +%Y%m%d).tar.gz /etc/xroad

# Backup database
sudo -u postgres pg_dump centerui_production > centerui-backup-$(date +%Y%m%d).sql

# Backup Security Server configuration
kubectl -n xroad exec deploy/ss-primary -- tar -czf /tmp/xroad-config.tar.gz /etc/xroad
kubectl -n xroad cp ss-primary-xxx:/tmp/xroad-config.tar.gz ./xroad-config-backup-$(date +%Y%m%d).tar.gz

# Backup PostgreSQL cluster
kubectl -n xroad exec postgres-xroad-pg-0 -- pg_dump -U xroad_app serverconf > backup-serverconf-$(date +%Y%m%d).sql
```

### Recovery

```bash
# Restore Central Server
sudo tar -xzf central-server-backup-20240101.tar.gz -C /

# Restore database
sudo -u postgres psql centerui_production < centerui-backup-20240101.sql

# Restore Security Server configuration
kubectl -n xroad cp xroad-config-backup-20240101.tar.gz ss-primary-xxx:/tmp/
kubectl -n xroad exec deploy/ss-primary -- tar -xzf /tmp/xroad-config-backup-20240101.tar.gz -C /
kubectl -n xroad restart deployment ss-primary

# Restore PostgreSQL cluster
kubectl -n xroad exec -i postgres-xroad-pg-0 -- psql -U xroad_app -d serverconf < backup-serverconf-20240101.sql
```

## Best Practices

### Security
- Regular security updates
- Strong passwords
- Network segmentation
- Access control
- Audit logging

### Performance
- Resource monitoring
- Capacity planning
- Performance tuning
- Load balancing
- Caching

### Reliability
- Regular backups
- Disaster recovery testing
- Health monitoring
- Alerting
- Documentation

### Maintenance
- Regular updates
- Log rotation
- Cleanup old data
- Performance monitoring
- Security scanning
