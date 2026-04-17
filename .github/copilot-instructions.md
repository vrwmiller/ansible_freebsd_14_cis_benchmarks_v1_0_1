# Copilot Instructions — FreeBSD 14 CIS Ansible Role

This is an Ansible role implementing CIS FreeBSD 14 Benchmark v1.0.1.
Python 3.11, Ansible 2.16, ansible-lint at production profile.

---

## Branching and PRs

- Never commit directly to `main`. All changes go through a PR.
- Branch naming: `feat/<topic>`, `fix/<topic>`, `chore/<topic>` (lowercase, hyphen-separated).
- Open PRs with `gh pr create --body-file /tmp/<file>.txt`.
- Use merge commits (`gh pr merge --merge`).
- After merge: `git checkout main && git pull origin main && git branch -d <branch>`.

---

## Control Block Structure

Every CIS control is one top-level block. Pattern (canonical form from section_2.yml):

```yaml
- name: "<id> | Ensure <description>"
  when: "'<id>' not in active_exceptions"
  tags: [rule_<id>, level1|level2, section_<N>]
  block:

    - name: "<id> | AUDIT | <what is being checked>"
      ansible.builtin.command: <cmd>
      register: cis_<id_underscored>_<purpose>
      changed_when: <non-compliance condition>
      failed_when: false
      check_mode: false

    - name: "<id> | AUDIT | Report <state>"
      ansible.builtin.debug:
        msg: >-
          {{ 'NON-COMPLIANT: ...' if <condition> else 'COMPLIANT: ...' }}

    - name: "<id> | REMEDIATE | <action>"
      <module>:
        ...
      when:
        - freebsd_cis_remediate | bool
        - <raw audit condition>   # e.g. cis_x_x_x_foo.rc != 0  OR  cis_x_x_x_foo is changed
```

### Rules

- `check_mode: false` on every audit task — audits must run under `--check`.
- `failed_when: false` on audit tasks — non-compliance is not a task failure.
- `changed_when` on audit tasks encodes the compliance signal: `changed` = NON-COMPLIANT.
- Remediation `when` may use `result is changed` **or** raw `.rc`/`.stdout` — both are
  acceptable; prefer `is changed` for multi-register controls for clarity. Do not mix both
  styles within one control's remediation block.
- `freebsd_cis_remediate | bool` is always the first `when` condition on remediation tasks.
- Never modify host state in an audit task.
- `failed_when: false` is acceptable on remediation tasks when a "stop" may fail because the
  service is already stopped.

---

## Register Variable Naming

Pattern: `cis_<section_underscored>_<purpose>` — all lowercase, underscores only.

Examples:
- `cis_2_1_1_ntpd` — rc.conf enablement check for 2.1.1
- `cis_2_1_1_ntpd_running` — runtime process check for 2.1.1
- `cis_2_2_2_inetd_ftp` — inetd ftp audit for 2.2.2
- `cis_2_2_2_vsftpd_pkg` — vsftpd package check for 2.2.2

---

## Tags

Every control block gets exactly three tags: `[rule_<id>, level1|level2, section_<N>]`.
Additional tags are allowed for special cases: `automated`, `manual`.
- Add `automated` when remediation is fully automated.
- Add `manual` when the control requires operator action (e.g. 2.2.12).

---

## Exception Handling

Initialized in `tasks/main.yml`:
```yaml
active_exceptions: "{{ (freebsd_cis_global_exceptions + freebsd_cis_local_exceptions) | unique }}"
```
Every top-level control block has `when: "'<id>' not in active_exceptions"`.
Skipped controls appear as `skipped` in Ansible output — do not use `ignore_errors`.

---

## Defaults vs Vars

- `defaults/main.yml` — operator-tunable settings (`freebsd_cis_remediate`, `freebsd_cis_level`,
  exception lists, control-specific tunables like `freebsd_cis_tmp_size`). All should have comments.
- `vars/main.yml` — internal, non-overridable role metadata (`freebsd_cis_benchmark_version`, etc.).
- New control-specific tunables go in `defaults/main.yml` under the relevant section header comment.

---

## FreeBSD / Ansible Portability

- **grep patterns in `ansible.builtin.command`**: use POSIX ERE character classes (`[[:space:]]`,
  `[[:alpha:]]`) — `\s`, `\w` etc. are not portable on FreeBSD system grep with `-E`.
- **`ansible.builtin.replace` `regexp`**: uses Python `re` — use `\s`, `\w` etc.;
  `[[:space:]]` is NOT recognized by Python `re` and will silently not match.
- **inetd service reload**: use `state: reloaded`, not `state: restarted`. Reload sends SIGHUP to a
  running inetd; restart would start inetd on hosts where it is intentionally stopped.
- **FreeBSD service names**: verify rc.d script names exactly (e.g. `autofs` not `automount`,
  `cyrus-imapd` not `cyrus_imapd`).
- **Process names for `pgrep -x`**: verify the actual daemon binary name (e.g. `automountd` not
  `automount`).
- **Package removal globs**: `pkg remove -y -g 'pattern*'` — `-g` applies to one argument only.
  Use separate tasks for separate glob patterns.
- **inetd.conf patterns**: entries may have leading whitespace. Audit grep patterns should use
  `^[[:space:]]*<service>[[:space:]]`; replace regexps should use `^\s*<service>\s`.

---

## Lint

Target: `ansible-lint tasks/section_<N>.yml` (production profile).
Every section file must pass with 0 failures before merging. The comment `# lint-clean: production profile`
at the top of a section file records that baseline.
Run lint before committing any change to a `tasks/` file.

---

## File Layout

```
defaults/main.yml       # Operator tunables and exception lists
vars/main.yml           # Internal role metadata (benchmark name/version)
tasks/main.yml          # Orchestrator: merge exceptions, import sections
tasks/section_1.yml     # CIS Section 1 — Initial Setup
tasks/section_2.yml     # CIS Section 2 — Services
tasks/section_3.yml     # CIS Section 3 — Network (stub)
tasks/section_4.yml     # CIS Section 4 — Access, Authentication and Authorization (stub)
tasks/section_5.yml     # CIS Section 5 — Logging and Auditing (stub)
tasks/section_6.yml     # CIS Section 6 — System Maintenance (stub)
docs/DESIGN.md          # Canonical patterns and rationale
docs/ARCHITECTURE.md    # Data flow, modes, file inventory
docs/PROPOSAL.md        # Original scope and acceptance criteria
meta/main.yml           # Galaxy metadata
```

---

## Debug Output

When reporting multi-line command output in a `debug` task, use a list for `msg`:
```yaml
msg: "{{ ['Header line:', ''] + some_register.stdout_lines }}"
```
Ansible prints each list element on its own line. Using `stdout` as a string produces an escaped blob.
