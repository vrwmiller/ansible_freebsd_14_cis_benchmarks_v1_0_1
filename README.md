# Ansible FreeBSD 14 CIS Benchmarks (v1.0.1)

I have some cloud-based VPS's just upgraded from upcoming EOL'd FreeBSD 13 to FreeBSD 14.4. This being the first FreeBSD CIS Benchmark in 22 years, I wanted it applied as a baseline security measure.

Before running remediation mode, back up any files that may be modified. Run remediation in dry-run mode first with `--check`, review exactly what will change, and only then run remediation without `--check`.

An Ansible role for auditing and optionally remediating FreeBSD 14 hosts against CIS Benchmark v1.0.1 controls.

## What This Role Does

- Audits CIS controls by default — no host state is changed unless explicitly enabled.
- Marks non-compliant checks as `changed` in Ansible output for easy grep/reporting.
- Applies remediation only when `freebsd_cis_remediate: true`.
- Supports layered exception handling for environment-specific deviations.
- Audit-only mode (`freebsd_cis_remediate: false`) is safe to run on production hosts at any time.

## Modes

| Mode | Setting | Outcome |
| --- | --- | --- |
| Audit (default) | `freebsd_cis_remediate: false` | Reports non-compliance without changing host state |
| Remediation | `freebsd_cis_remediate: true` | Reports and applies defined fixes |
| Dry run | `--check` | Simulates remediation intent while validating execution paths |

## Section Coverage

5 of 6 CIS sections are implemented. Section 6 is a stub.

| Section | Title | Status | Controls |
| --- | --- | --- | --- |
| 1 | Initial Setup | Implemented | 1.1.1.1 – 1.6.5 |
| 2 | Services | Implemented | 2.1.1 – 2.2.12 |
| 3 | Network | Implemented | 3.1.1 – 3.4.1.2 |
| 4 | Access, Authentication and Authorization | Implemented | 4.1.1.1 – 4.5.3.2 |
| 5 | Logging and Auditing | Implemented | 5.1.1.1 – 5.3.2 |
| 6 | System Maintenance | Stub | — |

### Level gating

- Level 1 controls run when `freebsd_cis_level: 1` (default).
- Level 2 controls are gated by `freebsd_cis_level | int >= 2`. This includes the BSM/audit subsystem controls (5.2.x) and higher-risk network controls.

### Manual controls

Some controls emit COMPLIANT/NON-COMPLIANT but cannot be fully auto-remediated — they require operator review or site-specific configuration. These are tagged `manual`. Examples:
- **5.1.1.5** — Remote syslog forwarding: the audit detects any remote logging mechanism (syslog `@remote`, Splunk UF, rsyslog, syslog-ng). Automated `syslog.conf` remediation is only applied when `freebsd_cis_syslog_remote_host` is set.
- **5.1.1.3** — newsyslog.conf log file permissions: flags a permissions violation, but site-specific log rotation configs may intentionally vary.
- **2.2.12** — Other inetd-managed services: requires operator review of each entry.

### Pre-flight behavior

The role includes pre-flight `stat` checks for optional files and binaries. When a dependency is absent, the role warns and guards remediation tasks that require that file or binary — audit tasks may still run and report non-compliance. The play does not fail. Affected items:
- `/etc/security/audit_control` — required for Section 5.2.x BSM controls
- `/etc/syslog.conf` — required for Section 5.1.1.5 syslog forwarding remediation
- AIDE binary (`/usr/local/bin/aide`) — required for Section 5.3.2 file integrity checks

### Handlers

The handler `Resync auditd` runs `/usr/sbin/audit -s` after any change to `/etc/security/audit_control`. This ensures audit configuration changes take effect immediately without a full audit daemon restart.

## Exception Model

Two lists merge into one active exceptions set used by each control:

```yaml
freebsd_cis_global_exceptions: []   # role-level skips
freebsd_cis_local_exceptions: []    # playbook/host-level skips
```

Effective set computed in `tasks/main.yml`:
```yaml
active_exceptions: "{{ (freebsd_cis_global_exceptions + freebsd_cis_local_exceptions) | unique }}"
```

Skipped controls appear as `skipped` in Ansible output.

## Variables Reference

All operator-tunable variables live in `defaults/main.yml`.

### Core

| Variable | Default | Description |
| --- | --- | --- |
| `freebsd_cis_remediate` | `false` | Enable remediation. `false` = audit-only. |
| `freebsd_cis_level` | `1` | CIS profile level (1 or 2). Level 2 enables additional controls. |
| `freebsd_cis_global_exceptions` | `[]` | Rule IDs to skip at the role level. |
| `freebsd_cis_local_exceptions` | `[]` | Rule IDs to skip at the playbook or host level. |

### Section 1 — Initial Setup

| Variable | Default | Description |
| --- | --- | --- |
| `freebsd_cis_tmp_size` | `"2g"` | tmpfs size for `/tmp` when enabling tmpfs via sysrc (1.1.2.1.1). |
| `freebsd_cis_bootloader_password` | `""` | Bootloader password written to `/boot/loader.conf`. Empty = skip. **Stored in plaintext.** |
| `freebsd_cis_warning_banner` | `"Authorized users only. All activity may be monitored and reported."` | Warning banner text for `/etc/motd`, `/etc/issue`, and `/etc/issue.net` (1.6.1–1.6.3). |

### Section 4 — Access, Authentication and Authorization

| Variable | Default | Description |
| --- | --- | --- |
| `freebsd_cis_sshd_source` | `"base"` | SSH implementation: `base` (FreeBSD base sshd) or `ports` (ports OpenSSH). Derives paths and service name. |
| `freebsd_cis_sshd_config` | *(derived)* | Path to `sshd_config`. |
| `freebsd_cis_sshd_bin` | *(derived)* | Path to `sshd` binary. |
| `freebsd_cis_ssh_bin` | *(derived)* | Path to `ssh` binary. |
| `freebsd_cis_sshd_service` | *(derived)* | rc.d service name (`sshd` or `openssh`). |
| `freebsd_cis_sshd_allow_users` | `""` | `AllowUsers` value. Empty = skip remediation. |
| `freebsd_cis_sshd_allow_groups` | `""` | `AllowGroups` value. Empty = skip remediation. |
| `freebsd_cis_sshd_deny_users` | `""` | `DenyUsers` value. Empty = skip remediation. |
| `freebsd_cis_sshd_deny_groups` | `""` | `DenyGroups` value. Empty = skip remediation. |
| `freebsd_cis_sshd_banner` | `/etc/issue.net` | Banner file path sent to remote users before authentication (4.2.5). |
| `freebsd_cis_sshd_weak_ciphers` | `"3des-cbc,aes128-cbc,aes192-cbc,aes256-cbc,rijndael-cbc@lysator.liu.se"` | Comma-separated list of weak ciphers to remove (minus-prefix syntax, 4.2.6). |
| `freebsd_cis_sshd_client_alive_interval` | `15` | `ClientAliveInterval` in seconds (4.2.7). |
| `freebsd_cis_sshd_client_alive_count_max` | `3` | `ClientAliveCountMax` (4.2.7). |
| `freebsd_cis_sshd_weak_kex` | `"diffie-hellman-group1-sha1,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1"` | Weak key-exchange algorithms to remove (4.2.11). |
| `freebsd_cis_sshd_login_grace_time` | `60` | `LoginGraceTime` in seconds (4.2.12). |
| `freebsd_cis_sshd_log_level` | `"VERBOSE"` | sshd log verbosity (4.2.13). |
| `freebsd_cis_sshd_weak_macs` | abbreviated; see `defaults/main.yml` | Weak MAC algorithms to remove (4.2.14). Full list in `defaults/main.yml`. |
| `freebsd_cis_sshd_max_auth_tries` | `4` | `MaxAuthTries` (4.2.15). |
| `freebsd_cis_sshd_max_sessions` | `10` | `MaxSessions` (4.2.16). |
| `freebsd_cis_sshd_max_startups` | `"10:30:60"` | `MaxStartups` throttle (4.2.17). |
| `freebsd_cis_sudo_logfile` | `/var/log/sudo.log` | sudo log file path (4.3.3). |
| `freebsd_cis_sudo_timeout` | `15` | sudo credential cache timeout in minutes (4.3.6). |
| `freebsd_cis_pam_passwdqc_minlen` | `"disabled,14,12,8,6"` | `pam_passwdqc` minlen argument (4.4.1.1.1, 4.4.1.1.2). |
| `freebsd_cis_pw_max_age` | `365` | Maximum password age in days (4.5.1.2). |
| `freebsd_cis_pw_warn_days` | `7` | Password expiration warning in days (4.5.1.3). |

### Section 5 — Logging and Auditing

| Variable | Default | Description |
| --- | --- | --- |
| `freebsd_cis_syslog_remote_host` | `""` | FQDN/IP of remote syslog host for `syslog.conf` remediation (5.1.1.5). Empty = skip syslog.conf change. Audit always runs. |
| `freebsd_cis_log_files_to_fix` | *(list of `/var/log/...` paths)* | Log files to enforce `0640 root:wheel` or more restrictive on during remediation (5.1.3). |
| `freebsd_cis_audit_filesz` | `"2M"` | BSM audit trail max file size before rotation (5.2.2.1). |
| `freebsd_cis_audit_expire_after` | `"10M"` | BSM audit log minimum age/size before expiry (5.2.2.2). |

## Requirements

- Python 3.11
- Ansible 2.16
- FreeBSD 14 target hosts
- Local virtual environment in `venv/`

## Local Development

```bash
source venv/bin/activate
ansible-lint tasks/section_<N>.yml   # lint a single section
```

## Project Layout

```
defaults/main.yml       # Operator tunables and exception lists
vars/main.yml           # Internal role metadata (benchmark name/version)
tasks/main.yml          # Orchestrator: merge exceptions, import sections
tasks/section_1.yml     # CIS Section 1 — Initial Setup
tasks/section_2.yml     # CIS Section 2 — Services
tasks/section_3.yml     # CIS Section 3 — Network
tasks/section_4.yml     # CIS Section 4 — Access, Authentication and Authorization
tasks/section_5.yml     # CIS Section 5 — Logging and Auditing
tasks/section_6.yml     # CIS Section 6 — System Maintenance (stub)
handlers/main.yml       # Service reload/resync handlers
docs/DESIGN.md          # Canonical task patterns and rationale
docs/ARCHITECTURE.md    # Execution flow and file structure
docs/PROPOSAL.md        # Original project scope and acceptance criteria
meta/main.yml           # Galaxy metadata
```

## Security Notes

- Never commit real credentials or tokens.
- Treat external payloads as untrusted input.
- The `freebsd_cis_bootloader_password` variable is stored in **plaintext** in `/boot/loader.conf` — use with caution.

See `.github/instructions/security.instructions.md` for full policy.

