#!/usr/bin/env bash
# Activate the project virtual environment.
# To also install development dependencies, set INSTALL_DEV_REQUIREMENTS=1 when sourcing.
# Usage: source env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/venv/bin/activate"

if [ "${INSTALL_DEV_REQUIREMENTS:-0}" = "1" ]; then
	python -m pip install -r "${SCRIPT_DIR}/requirements-dev.txt"
else
	echo "Development dependencies not installed. Re-run with INSTALL_DEV_REQUIREMENTS=1 to install them."
fi
