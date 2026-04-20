#!/usr/bin/env bash
# ansible-lint pre-commit hook for FreeBSD CIS Ansible role
# Runs ansible-lint at the production profile against all task files.

set -e

if ! command -v ansible-lint >/dev/null 2>&1; then
  echo "Error: ansible-lint was not found in PATH." >&2
  echo "Activate the virtual environment (source venv/bin/activate) or install" >&2
  echo "development dependencies (pip install -r requirements-dev.txt), then re-run." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Running ansible-lint (production profile)..."
ansible-lint --profile production \
  "$REPO_ROOT/tasks/" \
  "$REPO_ROOT/handlers/" \
  "$REPO_ROOT/defaults/" \
  "$REPO_ROOT/vars/"

echo "✓ ansible-lint passed"
