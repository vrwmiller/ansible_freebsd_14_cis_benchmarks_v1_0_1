#!/bin/bash
# Syntax check for FreeBSD CIS Ansible role
# Validates YAML, Jinja2, and Ansible playbook syntax before commit

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Checking Ansible playbook syntax..."
ansible-playbook --syntax-check "$REPO_ROOT/tests/syntax-check-playbook.yml" \
  -i "$REPO_ROOT/tests/inventory.ini"

echo "✓ Syntax check passed"
