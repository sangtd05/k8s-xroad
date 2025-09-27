#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

docker volume create sidecar_config_volume >/dev/null
docker volume create sidecar_backup_volume >/dev/null
docker volume create sidecar_db_volume >/dev/null

mkdir -p compose
ENV_FILE="compose/.env"
if [ ! -f "$ENV_FILE" ]; then
  SS_PIN="$(openssl rand -hex 8)"
  SS_PASS="$(openssl rand -base64 24 | tr -d '\n')"
  cat > "$ENV_FILE" <<EOF
XROAD_TOKEN_PIN=${SS_PIN}
XROAD_ADMIN_USER=xrdadmin
XROAD_ADMIN_PASSWORD=${SS_PASS}
# Optional external DB for SS:
# XROAD_DB_HOST=localhost
# XROAD_DB_PORT=5432
# XROAD_DB_NAME=serverconf
# XROAD_DB_USER=xroad
# XROAD_DB_PASSWORD=CHANGE_ME_DB_PASS
EOF
  echo "compose/.env created with random PIN and password."
fi

cat > compose/docker-compose.yml <<'YML'
services:
  xroad-ss-mgmt:
    image: niis/xroad-security-server-sidecar:7.6.2
    container_name: xroad-ss-mgmt
    restart: unless-stopped
    env_file:
      - ./.env
    ports:
      - "127.0.0.1:4001:4000"  # SS admin UI (loopback)
      - "127.0.0.1:5588:5588"  # health
      - "8443:8443"            # internal HTTPS if needed
      - "5500:5500"            # X-Road message protocol
      - "5577:5577"            # X-Road management
    volumes:
      - sidecar_config_volume:/etc/xroad
      - sidecar_backup_volume:/var/lib/xroad
      - sidecar_db_volume:/var/lib/postgresql/16/main

volumes:
  sidecar_config_volume:
  sidecar_backup_volume:
  sidecar_db_volume:
YML

docker compose -f compose/docker-compose.yml up -d

echo "SS UI: https://127.0.0.1:4001/"
echo "Credentials:"
grep -E "XROAD_ADMIN_USER=|XROAD_ADMIN_PASSWORD=|XROAD_TOKEN_PIN=" "$ENV_FILE"
