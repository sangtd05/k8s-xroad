#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Build a minimal cert DB by "issuing" TSA cert into index for OCSP to know it
if ! grep -q "$(openssl x509 -in pki/tsa.crt -noout -serial | cut -d= -f2)" pki/intermediate/index.txt 2>/dev/null; then
  SERIAL_HEX="$(openssl x509 -in pki/tsa.crt -noout -serial | cut -d= -f2)"
  END_DATE="$(openssl x509 -in pki/tsa.crt -noout -enddate | cut -d= -f2)"
  # index format: V\texp\t\tserial\tsubject
  echo -e "V\t${END_DATE}\t\t${SERIAL_HEX}\tunknown\t$(openssl x509 -in pki/tsa.crt -noout -subject | sed 's/^subject= //')" >> pki/intermediate/index.txt
fi

echo "Starting OpenSSL OCSP responder on :8888"
exec openssl ocsp \
  -port 8888 \
  -index pki/intermediate/index.txt \
  -CA pki/ca-chain.crt \
  -rkey pki/private/ocsp.key.pem \
  -rsigner pki/ocsp.crt \
  -text
