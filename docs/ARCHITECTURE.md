# ARCHITECTURE.md

## Logic Flow
The role is built around a conditional execution pipeline. Each CIS control is processed using the following sequence:

1. **Exception Check**: Determine whether the rule ID exists in the `active_exceptions` list. If present, the rule is skipped (Blue/Cyan).
2. **Audit Phase**: Execute a validation step (command, module, or fact-based check). If the system meets the benchmark, return `ok` (Green). If it does not, return `changed` (Yellow).
3. **Remediation Phase**: If the audit result is `changed` and `freebsd_cis_remediate` is set to `true`, run the corresponding remediation task.

## Data Merging Strategy
Exception handling is initialized during role setup using a `set_fact` operation:

- **Global Exceptions**: Defined in `defaults/main.yml`.
- **Local Exceptions**: Supplied via the playbook or `host_vars`.
- **Merged Result**:  
  `active_exceptions: "{{ role_defaults | union(playbook_vars) }}"`

## Mode Definitions

| Variable | Mode | Behavior |
| :--- | :--- | :--- |
| `freebsd_cis_remediate: false` | **Audit (Default)** | Flags non-compliance as "changed" without making modifications. |
| `freebsd_cis_remediate: true` | **Remediation** | Flags non-compliance and applies corrective actions. |
| `--check` | **Dry Run** | Simulates remediation changes; validates audit execution. |

## File Structure
- `defaults/main.yml`: Contains global variables and default accepted states.
- `vars/main.yml`: Stores internal benchmark-related metadata.
- `tasks/main.yml`: Acts as the orchestrator—merging exceptions and including subtask files.
- `tasks/audit/`: Holds audit logic organized by CIS sections.
- `tasks/remediate/`: Contains remediation logic, executed conditionally.
