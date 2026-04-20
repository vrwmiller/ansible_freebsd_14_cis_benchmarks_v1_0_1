#!/usr/bin/env bash
# Syntax check for FreeBSD CIS Ansible role
# Validates YAML, Jinja2, and Ansible playbook syntax before commit

set -e

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook was not found in PATH." >&2
  echo "Install Ansible (for example: python3 -m pip install ansible-core) or activate the correct virtual environment, then re-run this check." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Checking Ansible playbook syntax..."
ansible-playbook --syntax-check "$REPO_ROOT/tests/syntax-check-playbook.yml" \
  -i "$REPO_ROOT/tests/inventory.ini"

echo "✓ Syntax check passed"
