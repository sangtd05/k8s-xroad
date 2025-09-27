#!/usr/bin/env bash
set -euo pipefail
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y openssl python3 python3-venv python3-pip
# venv for TSA server
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
. .venv/bin/activate
pip install --upgrade pip
pip install flask waitress
echo "Deps OK"
