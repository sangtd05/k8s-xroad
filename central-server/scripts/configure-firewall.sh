#!/usr/bin/env bash
set -euo pipefail

if ufw status | grep -q "Status: active"; then
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw allow 4000/tcp
  ufw allow 5500/tcp
  ufw allow 5577/tcp
  echo "UFW rules added."
else
  echo "UFW disabled. Skipping."
fi
