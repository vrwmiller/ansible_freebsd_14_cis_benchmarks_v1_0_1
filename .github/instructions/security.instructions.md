---
description: "Security requirements for FreeBSD CIS Ansible role code and related automation."
applyTo: "**/*.py, **/*.sql, **/*.yaml, **/*.yml, **/*.tf, **/*.tfvars, **/*.auto.tfvars, **/*.tf.json, docs/DESIGN.md, env.sh"
---

# Security Standards - FreeBSD CIS Role

## Secrets and Credentials

- Never commit real credentials or tokens.
- Use placeholders in checked-in env templates.
- Route runtime secrets through secure secret management.

## Ansible Task Safety

- Prefer idempotent modules over raw shell/command where practical.
- If shell/command is required, constrain inputs and avoid interpolation of untrusted values.
- Always set explicit `changed_when` and `failed_when` for non-trivial checks.
- Use `check_mode: false` only when an audit must execute in dry runs, and document why.

## CIS Audit/Remediation Guardrails

- Audit logic must not modify host state.
- Remediation logic must run only when both are true:
  - the control is non-compliant
  - `freebsd_cis_remediate | bool`
- Respect exclusions consistently using `active_exclusions`.
- Avoid silent bypasses of controls due to broad or malformed exclusion checks.

## FreeBSD Hardening Safety

- Validate paths, service names, and sysctl keys before use.
- Prefer explicit allowlists for controlled values when practical.
- Ensure file permission changes use least privilege defaults.

## Terraform Security

### Forbidden Patterns

Do not write any of the following in Terraform:

- Any `password =` attribute assignment in a `.tf` file (including but not limited to database resources) — enforced by `scripts/check-terraform-secrets.sh` for `infra/*.tf`
- Any `random_password` resource in a `.tf` file (generated secrets are persisted in Terraform state) — enforced by `scripts/check-terraform-secrets.sh` for `infra/*.tf`
- `secret_string = jsonencode({...})` where the payload includes a plaintext password or token — policy rule; reviewers must enforce
- Any `aws_secretsmanager_secret_version` where `secret_string` is built such that a plaintext credential or token would be stored in Terraform state (use a managed-secret pattern instead) — policy rule; reviewers must enforce

Required pattern for RDS credentials:

- Use `manage_master_user_password = true` on `aws_db_instance`
- Reference the managed secret ARN from outputs or data sources — never construct credentials inline

### Few-Shot Examples

**Bad — credential in state:**

```hcl
resource "aws_db_instance" "main" {
  password = random_password.db.result  # persists plaintext credential in Terraform state
}
```

```hcl
resource "aws_secretsmanager_secret_version" "db" {
  secret_string = jsonencode({ password = var.db_password })  # plaintext in state
}
```

**Good — managed credential, no plaintext secret in state:**

```hcl
resource "aws_db_instance" "main" {
  manage_master_user_password = true  # AWS stores the secret; no plaintext password in Terraform state
}

output "db_secret_arn" {
  value = aws_db_instance.main.master_user_secret[0].secret_arn
}
```

### Pre-Write Constraint

Before writing any Terraform resource that handles credentials:

1. Confirm no secret value will be persisted in Terraform state.
2. If a secret value would enter state, stop and use a managed credential approach instead.

## Review Focus

Flag and block:
- injection paths in shell/command tasks
- unsafe remediation gating or control bypasses
- insecure secret handling
- non-idempotent behavior that creates drift risk
- plaintext credentials or tokens in Terraform state
