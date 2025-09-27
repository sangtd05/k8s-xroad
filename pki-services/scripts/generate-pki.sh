#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p pki/private pki/newcerts pki/intermediate/private pki/intermediate/newcerts
chmod 700 pki/private pki/intermediate/private
touch pki/index.txt pki/intermediate/index.txt
echo 1000 > pki/serial
echo 1000 > pki/intermediate/serial
echo 1000 > pki/crlnumber
echo 1000 > pki/intermediate/crlnumber

# Root key + cert
openssl genrsa -out pki/private/root.key.pem 4096
openssl req -x509 -new -nodes -key pki/private/root.key.pem -sha256 -days 3650 \
  -subj "/C=VN/O=DEV Root CA/CN=DEV-ROOT-CA" \
  -out pki/root.crt

# Intermediate key + CSR + cert
openssl genrsa -out pki/intermediate/private/intermediate.key.pem 4096
openssl req -new -key pki/intermediate/private/intermediate.key.pem \
  -subj "/C=VN/O=DEV Intermediate CA/CN=DEV-INTERMEDIATE-CA" \
  -out pki/intermediate.csr

cat > pki/openssl_intermediate_ext.cnf <<'EOF'
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
authorityKeyIdentifier = keyid:always,issuer
subjectKeyIdentifier = hash
authorityInfoAccess = OCSP;URI:http://127.0.0.1:8888
crlDistributionPoints = URI:http://127.0.0.1/crl.pem
EOF

openssl x509 -req -in pki/intermediate.csr -CA pki/root.crt -CAkey pki/private/root.key.pem \
  -CAcreateserial -out pki/intermediate.crt -days 1825 -sha256 \
  -extfile pki/openssl_intermediate_ext.cnf

# Chain
cat pki/intermediate.crt pki/root.crt > pki/ca-chain.crt

# OCSP signing cert
openssl genrsa -out pki/private/ocsp.key.pem 4096
openssl req -new -key pki/private/ocsp.key.pem \
  -subj "/C=VN/O=DEV OCSP/CN=DEV-OCSP" \
  -out pki/ocsp.csr

cat > pki/openssl_ocsp_ext.cnf <<'EOF'
basicConstraints = CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = OCSPSigning
authorityKeyIdentifier = keyid,issuer
subjectKeyIdentifier = hash
EOF

openssl x509 -req -in pki/ocsp.csr -CA pki/intermediate.crt -CAkey pki/intermediate/private/intermediate.key.pem \
  -CAcreateserial -out pki/ocsp.crt -days 825 -sha256 -extfile pki/openssl_ocsp_ext.cnf

# TSA signer cert (EKU timeStamping)
openssl genrsa -out pki/private/tsa.key.pem 4096
openssl req -new -key pki/private/tsa.key.pem \
  -subj "/C=VN/O=DEV TSA/CN=DEV-TSA" \
  -out pki/tsa.csr

cat > pki/openssl_tsa_ext.cnf <<'EOF'
basicConstraints = CA:false
keyUsage = critical, digitalSignature, nonRepudiation
extendedKeyUsage = timeStamping
authorityKeyIdentifier = keyid,issuer
subjectKeyIdentifier = hash
EOF

openssl x509 -req -in pki/tsa.csr -CA pki/intermediate.crt -CAkey pki/intermediate/private/intermediate.key.pem \
  -CAcreateserial -out pki/tsa.crt -days 825 -sha256 -extfile pki/openssl_tsa_ext.cnf

# OpenSSL DB files for OCSP
: > pki/intermediate/index.txt
echo 1000 > pki/intermediate/serial

# TSA config for openssl-ts
cat > pki/tsa.conf <<'CONF'
tsa_policy1 = 1.2.3.4.1
default_tsa = tsa_config1

[ tsa_config1 ]
dir = ./pki
serial = $dir/tsaserial
crypto_device = builtin
signer_cert = $dir/tsa.crt
certs = $dir/ca-chain.crt
signer_key = $dir/private/tsa.key.pem
default_policy = 1.2.3.4.1
digests = sha256
accuracy = secs:1, millisecs:0, microsecs:0
ordering = yes
tsa_name = yes
ess_cert_id_chain = no
CONF

echo 1000 > pki/tsaserial

echo "OK: Generated PKI in ./pki"
echo "CA chain : pki/ca-chain.crt"
echo "OCSP cert: pki/ocsp.crt"
echo "TSA cert : pki/tsa.crt"
