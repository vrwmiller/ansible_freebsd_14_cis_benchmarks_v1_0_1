# PROPOSAL.md

## Project Overview
The `ansible_freebsd_14_cis_benchmarks_v1_0_0` role automates the management of security compliance across FreeBSD 14 systems. It delivers a consistent approach for evaluating hosts against the CIS (Center for Internet Security) Benchmark v1.0.1 and, when enabled, correcting any identified deviations.

## Problem Statement
I have several FreeBSD VPS's and manually maintaining compliance is inefficient and susceptible to human error. Many existing solutions focus solely on auditing (leaving remediation to administrators) or exclusively on enforcement (introducing risk in production environments). This role addresses both gaps through a report-first model.

## Proposed Solution
A single Ansible Galaxy role that:

1. **Runs audits by default**, using Ansible’s `changed` status to flag non-compliant conditions without modifying the system.
2. **Allows rule exclusions** through a layered variable structure, enabling environment-specific overrides (e.g., relaxing SSH requirements on a bastion host).
3. **Performs remediation only when explicitly enabled**, ensuring administrators retain full control over when changes are applied.

## Expected Outcomes
- **Visibility:** Immediate insight into the compliance state across all managed FreeBSD systems.
- **Safety:** Audit mode runs without `--check`, enabling more comprehensive validation than standard check mode typically allows.
- **Flexibility:** Combined global and local exclusion handling allows security teams to define baselines while enabling operations teams to override specific rules as needed.
