#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

. .venv/bin/activate

python3 app/tsa_server.py
