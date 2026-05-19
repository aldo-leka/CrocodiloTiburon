#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
export DATAMULE_SEC_USER_AGENT="${DATAMULE_SEC_USER_AGENT:-Aldo Leka CrocodiloTiburon/0.1 lekabros@gmail.com}"
python tools/datamule_bridge.py resolve AAPL
