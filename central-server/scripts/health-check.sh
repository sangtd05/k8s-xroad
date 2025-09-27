#!/usr/bin/env bash
set -euo pipefail

echo "== systemd =="
systemctl --no-pager --full status xroad-center xroad-center-registration-service xroad-center-management-service xroad-signer xroad-nginx || true

echo "== docker =="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo "== ports =="
ss -tlpn | grep -E ":(80|443|4000|4001|5500|5577)\s" || true

echo "== curl =="
echo "CS UI:"
curl -k -I https://127.0.0.1:4000/ || true
echo "SS health:"
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5588 || true
