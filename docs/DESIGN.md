# DESIGN.md

## Python and Ansible Requirements

* Must be python 3.11-compatible
* Deployed in a Python venv 
* Has an appropriate env.sh that activates the python venv
* Must be Ansible 2.16-compatible

## Task Implementation Pattern
Each CIS control is defined as a block to keep audit and remediation logic grouped together.

```yaml
# Example: CIS 1.1.1 (Audit and Remediation)
- name: "1.1.1 | Audit | Ensure /tmp is a separate partition"
  block:
    - name: "1.1.1 | Audit"
      shell: "mount | grep 'on /tmp '"
      register: _cis_1_1_1_audit
      failed_when: false
      changed_when: _cis_1_1_1_audit.rc != 0
      check_mode: false  # Force execution even in --check mode

    - name: "1.1.1 | Remediate"
      ansible.builtin.debug:
        msg: "Applying fix for /tmp partition..."
      # Replace with actual remediation logic
      when: 
        - _cis_1_1_1_audit.changed
        - freebsd_cis_remediate | bool
  when: "'1.1.1' not in active_exceptions"
  tags: [cis_1_1_1, section_1]
```

## Exception Handling Initialization

```yaml
- name: "Initialize Compliance Configuration"
  set_fact:
    active_exceptions: "{{ (freebsd_cis_global_exceptions + freebsd_cis_local_exceptions) | unique }}"
```


## Layout Recommendations

### Return States & Visual Indicators

| Ansible Status | Color | Mode | Meaning |
| --- | --- | --- | --- |
| `ok` | Green | Any | Check passed — system is compliant |
| `changed` | Yellow | Audit | Check failed — non-compliance detected, no changes made |
| `changed` | Yellow | Remediation | Check failed — remediation applied successfully |
| `skipped` | Blue/Cyan | Any | Rule ID is in `active_exceptions` — not evaluated |
| `failed` | Red | Any | Unexpected error during audit or remediation task |

### Variable Naming Conventions
- `freebsd_cis_remediate`: Boolean flag controlling whether remediation is applied (default: false).
- `freebsd_cis_global_exceptions`: List of rule IDs defined at the role level.
- `freebsd_cis_local_exceptions`: List of rule IDs defined by the user (playbook or host-level).
- `_cis_<id>_audit`: Internal variables used to store audit results for each rule.

