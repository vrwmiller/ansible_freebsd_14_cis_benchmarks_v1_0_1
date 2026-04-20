#!/usr/bin/env bash
# Activate the project virtual environment and install development dependencies.
# Usage: source env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/venv/bin/activate"

python -m pip install -r "${SCRIPT_DIR}/requirements-dev.txt"
