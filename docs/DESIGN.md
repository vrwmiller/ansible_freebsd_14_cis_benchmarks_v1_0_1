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
      register: cis_1_1_1_mount
      failed_when: false
      changed_when: cis_1_1_1_mount.rc != 0
      check_mode: false  # Force execution even in --check mode

    - name: "1.1.1 | Remediate"
      ansible.builtin.debug:
        msg: "Applying fix for /tmp partition..."
      # Replace with actual remediation logic
      when: 
        - cis_1_1_1_mount.rc != 0   # Use .rc directly, not .changed
        - freebsd_cis_remediate | bool
  when: "'1.1.1' not in active_exceptions"
  tags: [rule_1.1.1, level1, section_1]
```

### Remediation gate: `.rc` vs `.changed`

Remediation `when` conditions **must use the raw result variable directly** (e.g. `result.rc == 0`,
`result.rc != 0`, `result.stdout | trim != '1'`) rather than `result.changed`.

Rationale: `result.changed` is a derived Ansible attribute set by `changed_when` at task execution
time. If `changed_when` is ever edited, or a task is refactored to a different module, the
`.changed` gate can silently diverge from the actual compliance signal. Using `.rc` (or the
appropriate raw output field) makes the remediation condition self-contained and explicit — it reads
the same raw signal the audit task used, regardless of how `changed_when` is expressed.

Both approaches are semantically equivalent when `changed_when` is set correctly, but `.rc`-based
conditions are preferred for long-term maintainability in this role.

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
- `cis_<id>_<purpose>`: Internal variables used to store audit/remediation task results for each rule (for example: `cis_1_1_1_1_kld`, `cis_1_1_2_1_1_mount`).

---

## Benchmark Fidelity and Known Divergences

The CIS FreeBSD 14 Benchmark v1.0.1 is treated as the authoritative baseline for this role.
However, the benchmark is a living document with known limitations: it can contain platform-wrong
mappings, technically inaccurate audit procedures, Linux-derived guidance copied without FreeBSD
adaptation, and misleading control titles that do not match the actual resource being audited.

**Policy**: when our implementation diverges from the benchmark wording or procedure for correctness
reasons, the divergence must be documented — in the task name, an inline comment, or this section —
rather than silently complied with. An audit that faithfully implements a wrong procedure produces
worse results than one that documents and corrects it.

### Classification of divergences

| Type | Description | Example |
|---|---|---|
| **Platform mismap** | Benchmark references a Linux daemon/path/syscall that does not exist or has a different name on FreeBSD | 5.1.1.6 title says "rsyslog" — FreeBSD base uses `syslogd` |
| **Inaccurate audit procedure** | The prescribed check would produce false COMPLIANT or false NON-COMPLIANT results | 5.1.3 originally prescribed `find -maxdepth 1` — misses subdirectory logs |
| **Missing FreeBSD context** | Benchmark omits FreeBSD-specific facts that affect compliance determination | `pkg query -g` exits 0 on no match — `rc` alone cannot determine AIDE presence |
| **Title/content mismatch** | Control title does not match the actual resource audited or remediated | 5.1.1.6 audits `syslogd_flags`, not rsyslog configuration |

### Known divergences in this role

#### 5.1.1.6 — Control title says "rsyslog"; implementation audits `syslogd`
The CIS benchmark title for this control is Linux-derived and names rsyslog. FreeBSD 14 base ships
`syslogd`, not rsyslog. The block name preserves the verbatim CIS title (required for traceability);
task names correctly reference `syslogd` and `syslogd_flags`. rsyslog/syslog-ng are not installed on
a stock FreeBSD 14 system — auditing third-party daemon remote-receive configuration is
operator-scope, not CIS baseline scope.

#### 5.1.1.1 — Original CIS check tested `syslogd_enable`, not installation
The benchmark intent is "syslog is installed". Checking `syslogd_enable` (rc.conf) detects boot-time
enablement, not presence of the binary — a host with syslogd deleted but rc.conf unchanged would
pass. Corrected to `test -x /usr/sbin/syslogd && test -x /etc/rc.d/syslogd`. 5.1.1.2 covers
enablement separately.

#### 5.1.3 — CIS implies "all logfiles"; original implementation scanned only top-level
`-maxdepth 1` on `find /var/log` misses logs written by services that log under
`/var/log/<service>/` (nginx, pkg, etc.). Removed depth limit to match the control's intent of
auditing all log files.

#### 5.2.4.x — `pkg query -g` exit code does not indicate match/no-match
`pkg query` exits 0 regardless of whether the glob matched anything. Using `rc != 0` as the
non-installed signal silently marks AIDE as installed on any host where pkg is functional. Corrected
to `stdout | trim == ''` as the authoritative no-match indicator.

#### 5.2.4.1+ — Audit directory extraction must use `exit` in awk to prevent multi-line output
`awk '/^dir/'` without an exit clause would return multiple lines if `audit_control` had more than
one `dir:` entry, producing an invalid path for `stat`. Corrected to `/^dir:/ {print $2; exit}`.

#### 5.2.3.x — `ansible.builtin.replace` silently no-ops when `flags:` line is absent
The benchmark's implied remediation (append to existing flags) fails on a host where
`/etc/security/audit_control` lacks a `flags:` directive entirely. Corrected to
read-current/set_fact-merge/lineinfile so the line is created if absent.

