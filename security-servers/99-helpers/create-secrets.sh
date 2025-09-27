#!/usr/bin/env bash
set -euo pipefail
NAMESPACE=${1:-xroad}

kubectl create ns "$NAMESPACE" 2>/dev/null || true

# Generate SSH key if not provided
if [ ! -f ./id_ed25519 ]; then
  ssh-keygen -t ed25519 -N "" -f ./id_ed25519 -C "xroad-sync-key"
fi

kubectl -n "$NAMESPACE" apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: xroad-secrets
  namespace: xroad
type: Opaque
stringData:
  XROAD_TOKEN_PIN: "CHANGE_ME_PIN"
  XROAD_ADMIN_USER: "xrdadmin"
  XROAD_ADMIN_PASSWORD: "CHANGE_ME_STRONG_PASSWORD"
  XROAD_DB_HOST: "xroad-pg.xroad.svc.cluster.local"
  XROAD_DB_PORT: "5432"
  XROAD_DB_NAME: "serverconf"
  XROAD_DB_USER: "xroad_app"
  XROAD_DB_PASSWORD: "CHANGE_ME_DB_PASS"
YAML

kubectl -n "$NAMESPACE" create secret generic xroad-ssh --from-file=ssh-privatekey=./id_ed25519 --from-file=ssh-publickey=./id_ed25519.pub --type=kubernetes.io/ssh-auth --dry-run=client -o yaml | kubectl apply -f -

# Build db.properties secret
cat > /tmp/db.properties <<EOF
serverconf.hibernate.connection.url=jdbc:postgresql://xroad-pg.xroad.svc.cluster.local:5432/serverconf
serverconf.hibernate.connection.username=xroad_app
serverconf.hibernate.connection.password=CHANGE_ME_DB_PASS
serverconf.hibernate.connection.driver_class=org.postgresql.Driver

messagelog.hibernate.connection.url=jdbc:postgresql://xroad-pg.xroad.svc.cluster.local:5432/messagelog
messagelog.hibernate.connection.username=xroad_app
messagelog.hibernate.connection.password=CHANGE_ME_DB_PASS
messagelog.hibernate.connection.driver_class=org.postgresql.Driver

op-monitor.hibernate.connection.url=jdbc:postgresql://xroad-pg.xroad.svc.cluster.local:5432/opmonitor
op-monitor.hibernate.connection.username=xroad_app
op-monitor.hibernate.connection.password=CHANGE_ME_DB_PASS
op-monitor.hibernate.connection.driver_class=org.postgresql.Driver
EOF

kubectl -n "$NAMESPACE" create secret generic xroad-db-properties --from-file=db.properties=/tmp/db.properties --dry-run=client -o yaml | kubectl apply -f -
echo "Secrets created. Remember to replace CHANGE_ME_ values."
