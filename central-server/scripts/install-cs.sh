#!/usr/bin/env bash
set -euo pipefail

install -d -m 0755 /usr/share/keyrings
curl -fsSL https://x-road.eu/gpg/key/public/niis-artifactory-public.gpg \
  -o /usr/share/keyrings/niis-artifactory-keyring.gpg

CODENAME="$(lsb_release -sc)"
echo "deb [signed-by=/usr/share/keyrings/niis-artifactory-keyring.gpg] https://artifactory.niis.org/xroad-release-deb ${CODENAME}-current main" \
  > /etc/apt/sources.list.d/xroad.list

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y xroad-centralserver postgresql

systemctl enable --now postgresql
systemctl enable --now xroad-center xroad-center-registration-service xroad-center-management-service xroad-signer xroad-nginx || true

echo "Central Server installed. Open https://<FQDN-CS>:4000/ to initialize."
