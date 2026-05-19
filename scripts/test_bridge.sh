#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m py_compile tools/datamule_bridge.py
python3 tools/datamule_bridge.py resolve AAPL
python3 tools/datamule_bridge.py search AAPL --forms 10-K --start 2024-01-01 --end 2025-12-31 > /tmp/crocodilo_search_test.json
python3 - <<'PY'
import json
payload = json.load(open('/tmp/crocodilo_search_test.json'))
assert payload['ok'] is True
assert payload['count'] >= 1
print(f"bridge ok: {payload['count']} filing hit(s)")
PY
