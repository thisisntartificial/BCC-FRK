#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the ecc-universal repository.
# Prepares Node.js (yarn) and Python (src/llm) dependencies plus the system
# package required by the Tkinter dashboard (ecc_dashboard.py).
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

# System dependency for the Tkinter dashboard: `npm run dashboard` / ecc_dashboard.py.
if ! python3 -c "import tkinter" >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends python3-tk
fi

# Node dependencies using the pinned Yarn (Berry) version via Corepack.
corepack enable
corepack prepare yarn@4.9.2 --activate
yarn install --immutable

# Python LLM abstraction library plus dev tooling (pytest, ruff, mypy).
python3 -m pip install -e ".[dev]"

echo "ECC environment bootstrap complete."
