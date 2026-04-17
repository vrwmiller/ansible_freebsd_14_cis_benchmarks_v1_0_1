# Ansible FreeBSD 14 CIS Benchmarks (v1.0.1)

I have a few VPS' in the cloud and want to implement FreeBSD 14 CIS Benchmarks on them. This repository defines an Ansible role pattern for auditing and optionally remediating FreeBSD 14 hosts against CIS Benchmark v1.0.1 controls.

## What This Project Does

- Audits CIS controls by default.
- Marks non-compliant checks as `changed` in Ansible output.
- Applies remediation only when explicitly enabled.
- Supports layered exception handling for environment-specific deviations.

## Core Behavior

The role is designed as a conditional pipeline per control:

1. Exception check: skip rule if it is in the merged exceptions list.
2. Audit step: run check logic and set status.
3. Remediation step: run fix logic only when both conditions are true:
	- the audit indicates non-compliance
	- `freebsd_cis_remediate` is `true`

## Modes

| Mode | Setting | Outcome |
| --- | --- | --- |
| Audit (default) | `freebsd_cis_remediate: false` | Reports non-compliance without changing host state |
| Remediation | `freebsd_cis_remediate: true` | Reports and applies defined fixes |
| Dry run | `--check` | Simulates remediation intent while validating execution paths |

## Exception Model

Two lists are merged into one active list used by each control:

- `freebsd_cis_global_exceptions`
- `freebsd_cis_local_exceptions`

Effective set:

- `active_exceptions: "{{ (freebsd_cis_global_exceptions + freebsd_cis_local_exceptions) | unique }}"`

## Project Layout

- `docs/PROPOSAL.md`: project goals and rationale
- `docs/DESIGN.md`: implementation conventions and task pattern
- `docs/ARCHITECTURE.md`: execution flow and file structure

Expected role layout (as implementation expands):

- `defaults/main.yml`
- `vars/main.yml`
- `tasks/main.yml`
- `tasks/audit/`
- `tasks/remediate/`

## Requirements

- Python 3.11
- Ansible 2.16
- FreeBSD 14 target hosts
- Existing local virtual environment in `venv/`

## Local Development

Activate the existing environment:

```bash
source venv/bin/activate
```

Install or verify Ansible as needed in that environment.

## Security Notes

- Never commit real credentials or tokens.
- Treat external payloads as untrusted input.
- Validate and sanitize user-provided input.
- In Terraform, avoid patterns that persist plaintext credentials in state.

See `.github/instructions/security.instructions.md` for full policy.

## Current Status

This repository currently contains architecture, design, and proposal documentation that define the implementation contract for the role.

