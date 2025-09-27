# PKI Services (CA, OCSP, TSA)

Cung cấp các dịch vụ PKI cho Central Server: Certificate Authority, OCSP Responder và Timestamping Authority.

## Tổng quan

PKI Services bao gồm:
- **Root CA + Intermediate CA**: Tạo certificate chain
- **OCSP Responder**: Kiểm tra trạng thái certificate (port 8888)
- **RFC3161 TSA**: Timestamping service (port 3000)

## Yêu cầu hệ thống

- **OS**: Ubuntu/Debian
- **OpenSSL**: Cho PKI operations
- **Python 3**: Cho TSA server
- **Ports**: 8888 (OCSP), 3000 (TSA)

## Triển khai

### 1. Cài đặt dependencies
```bash
sudo ./scripts/install-dependencies.sh
```

### 2. Tạo PKI
```bash
sudo ./scripts/generate-pki.sh
```

### 3. Khởi động OCSP Responder
```bash
sudo ./scripts/start-ocsp.sh
```

### 4. Khởi động TSA Server
```bash
./scripts/start-tsa.sh
```

### 5. Deploy tất cả (recommended)
```bash
sudo ./deploy.sh
```

## Cấu hình trong Central Server

### 1. Import CA Chain
- Truy cập Central Server UI: `https://<CS-FQDN>:4000/`
- Vào **Approved CAs**
- Import file: `pki/ca-chain.crt`

### 2. Cấu hình OCSP
- Vào **OCSP Responders**
- URL: `http://<PKI-HOST>:8888`
- Certificate: `pki/ocsp.crt`

### 3. Cấu hình TSA
- Vào **Timestamping Services**
- URL: `http://<PKI-HOST>:3000/api/v1/timestamp`
- Certificate: `pki/tsa.crt`

## Kiểm thử

### OCSP Test
```bash
# Kiểm tra trạng thái TSA certificate
openssl ocsp -issuer pki/intermediate.crt -cert pki/tsa.crt \
  -url http://127.0.0.1:8888 -resp_text -noverify
```

### TSA Test
```bash
# Tạo timestamp request
echo "hello world" > test-message.txt
openssl ts -query -data test-message.txt -cert -sha256 -out timestamp-request.tsq

# Gửi request tới TSA
curl -s -H "Content-Type: application/timestamp-query" \
  --data-binary @timestamp-request.tsq \
  http://127.0.0.1:3000/api/v1/timestamp -o timestamp-response.tsr

# Verify response
openssl ts -reply -in timestamp-response.tsr -text -token_out
```

## Cấu trúc PKI

```
pki/
├── private/
│   ├── root.key.pem          # Root CA private key
│   ├── intermediate.key.pem  # Intermediate CA private key
│   ├── ocsp.key.pem          # OCSP signing key
│   └── tsa.key.pem           # TSA signing key
├── root.crt                  # Root CA certificate
├── intermediate.crt          # Intermediate CA certificate
├── ca-chain.crt              # Full certificate chain
├── ocsp.crt                  # OCSP responder certificate
├── tsa.crt                   # TSA certificate
├── tsa.conf                  # TSA configuration
└── tsaserial                 # TSA serial number file
```

## Security Notes

### Private Keys
- Tất cả private keys được tạo với 4096-bit RSA
- Keys được bảo vệ với permissions 600
- Nên backup keys an toàn

### Certificate Validity
- Root CA: 10 years
- Intermediate CA: 5 years
- OCSP/TSA certificates: 2+ years

### Network Security
- OCSP và TSA chỉ nên accessible từ Central Server
- Sử dụng firewall để restrict access
- Cân nhắc sử dụng HTTPS cho production

## Troubleshooting

### OCSP Issues
```bash
# Kiểm tra OCSP process
ps aux | grep ocsp

# Kiểm tra logs
journalctl -u ocsp-responder

# Test OCSP locally
openssl ocsp -port 8888 -index pki/intermediate/index.txt \
  -CA pki/ca-chain.crt -rkey pki/private/ocsp.key.pem \
  -rsigner pki/ocsp.crt -text
```

### TSA Issues
```bash
# Kiểm tra TSA process
ps aux | grep tsa_server

# Kiểm tra logs
tail -f tsa-server.log

# Test TSA API
curl -I http://127.0.0.1:3000/api/v1/timestamp/certchain
```

### Certificate Issues
```bash
# Kiểm tra certificate validity
openssl x509 -in pki/tsa.crt -text -noout

# Kiểm tra certificate chain
openssl verify -CAfile pki/ca-chain.crt pki/tsa.crt

# Kiểm tra OCSP certificate
openssl x509 -in pki/ocsp.crt -text -noout
```

## Production Deployment

### Systemd Services
Tạo systemd services cho OCSP và TSA:

```bash
# OCSP Service
sudo tee /etc/systemd/system/ocsp-responder.service > /dev/null <<EOF
[Unit]
Description=X-Road OCSP Responder
After=network.target

[Service]
Type=simple
User=ocsp
WorkingDirectory=/opt/xroad-pki
ExecStart=/usr/bin/openssl ocsp -port 8888 -index pki/intermediate/index.txt -CA pki/ca-chain.crt -rkey pki/private/ocsp.key.pem -rsigner pki/ocsp.crt
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# TSA Service
sudo tee /etc/systemd/system/tsa-server.service > /dev/null <<EOF
[Unit]
Description=X-Road TSA Server
After=network.target

[Service]
Type=simple
User=tsa
WorkingDirectory=/opt/xroad-pki
ExecStart=/opt/xroad-pki/.venv/bin/python app/tsa_server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

### Monitoring
- Monitor OCSP response times
- Monitor TSA request/response rates
- Monitor certificate expiration dates
- Set up alerts for service failures