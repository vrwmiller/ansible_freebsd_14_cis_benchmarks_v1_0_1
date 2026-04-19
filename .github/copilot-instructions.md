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
- Never use heredocs or `python3 -c` for multi-line content. Write all scripts and data to `/tmp/` files with `create_file`, execute them, then delete.

---

## Control Block Structure

Every CIS control is one top-level block. Target pattern (see `docs/DESIGN.md`):

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
        - <raw audit condition>   # e.g. cis_x_x_x_foo.rc != 0 OR cis_x_x_x_foo.stdout != 'expected'
```

### Rules

- `check_mode: false` on every audit task — audits must run under `--check`.
- `failed_when: false` on audit tasks — non-compliance is not a task failure.
- `changed_when` on audit tasks encodes the compliance signal: `changed` = NON-COMPLIANT.
- Remediation `when` must use raw audit signals (`.rc`, `.stdout`, `.rc == 0` etc.) rather
  than `result is changed`. `is changed` is a derived attribute — if `changed_when` is later
  edited the gate silently diverges from the real compliance signal. See docs/DESIGN.md for
  rationale. Do not use `is changed` as a remediation gate.
- `freebsd_cis_remediate | bool` is always the first `when` condition on remediation tasks.
- Never modify host state in an audit task.
- `failed_when: false` is acceptable on remediation tasks when a "stop" may fail because the
  service is already stopped.
- **`|| true` is banned in REMEDIATE shell/command tasks.** It swallows real errors and can
  mask false-COMPLIANT results. Use `failed_when: false` instead.
- Every `stat` task used for compliance checks must carry `failed_when: false` — `ansible.builtin.stat`
  does not error on a missing path (it returns `stat.exists: false`), but can fail due to permission
  errors or unexpected module failures. `failed_when: false` ensures non-compliance is never masked
  by a task error and the play continues to the report task.

---

## Register Variable Naming

Pattern: `cis_<id_underscored>_<purpose>` — all lowercase, underscores only.

Examples:
- `cis_2_1_1_ntpd` — rc.conf enablement check for 2.1.1
- `cis_2_1_1_ntpd_running` — runtime process check for 2.1.1
- `cis_2_2_2_inetd_ftp` — inetd ftp audit for 2.2.2
- `cis_2_2_2_vsftpd_pkg` — vsftpd package check for 2.2.2

---

## Tags

Every control block must include at least these three baseline tags: `[rule_<id>, level1|level2, section_<N>]`.
Additional tags are allowed for special cases: `automated`, `manual`.
- Add `automated` when remediation is fully automated.
- Add `manual` when the control requires operator action (e.g. 2.2.12).
- **Tags must be accurate.** Do not default all controls to `manual`. `automated` vs `manual`
  drives tooling filters and reporting — an incorrect tag is a silent defect.

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
- **`regex_search()` in `when:` conditions must append `is not none`.** `regex_search()` returns
  the matched string on success or `None` on no-match. Ansible's conditional evaluator requires a
  boolean; a bare string raises `Conditional result was derived from value of type 'str'`. Always
  write `cis_foo.stdout | regex_search('pattern') is not none`.
- **`when:` list items that contain inline dict literals must be quoted.** A Jinja2 expression
  containing `{...}` — e.g. `(cis_foo_stat.stat | default({'exists': false})).exists` — is parsed
  as a YAML mapping by ansible-lint and causes `schema[tasks]` failures. Quote the entire condition
  as a YAML string, or restructure to avoid inline dict literals altogether.
- **POSIX file permission checks**: use digit-based mode inspection in awk — extract the numeric
  mode string, strip leading zeros (`gsub(/^0+/,"",m)`), and check each digit position
  independently. Do not use `perm /o+r` style for multi-digit mode thresholds.

---

## Audit Safety Patterns

These patterns prevent the three most common classes of audit defect:
false-COMPLIANT results, silent remediation failures, and path injection.

### Optional-file audits (false-COMPLIANT prevention)

If an audit reads a file that may not exist (e.g. `/etc/newsyslog.conf`,
`/etc/security/audit_control`) and the read command is guarded only with
`2>/dev/null || true`, an absent file produces empty stdout. If `changed_when`
checks `stdout | trim != ''`, the task reports COMPLIANT when the file doesn't
exist. Fix pattern:

```yaml
- name: "<id> | AUDIT | Check <file> exists"
  ansible.builtin.stat:
    path: /etc/some/file
  register: cis_X_X_X_stat
  changed_when: not cis_X_X_X_stat.stat.exists
  failed_when: false
  check_mode: false

- name: "<id> | AUDIT | <what>"
  ansible.builtin.shell: awk '...' /etc/some/file
  register: cis_X_X_X_result
  changed_when: cis_X_X_X_result.stdout | trim == ''
  failed_when: false
  check_mode: false
  when: cis_X_X_X_stat.stat.exists
```

The `stat` task itself should use `changed_when: not cis_X_X_X_stat.stat.exists`
so the absent-file case is flagged as NON-COMPLIANT.

### Optional-file remediations

If a `lineinfile` (or `replace`) targets a file that may not exist and
`create: false` is set, the task will fail the play when the file is absent.
Fix pattern:

1. One unconditional `stat` task early in the section, before first use
   → `register: cis_<name>_stat`, `check_mode: false`, `failed_when: false`.
2. One `debug` warn task when `not stat.stat.exists`.
3. All downstream `lineinfile` remediations carry `- cis_<name>_stat.stat.exists`
   as a `when:` condition.

### Optional-binary pre-flights

When a control audits or remediates using a binary that may not be installed
(e.g. AIDE, a ports package):

1. `stat` the binary first → `failed_when: false`.
2. Emit a `debug` warning if absent.
3. Guard audit and remediation tasks on the stat result.

### Path injection guard

When an audit reads a path value from a config file (e.g. `dir:` from
`/etc/security/audit_control`) and then interpolates it into a shell `find`,
`stat`, or `awk` command, validate the path before use:

```yaml
when:
  - freebsd_cis_remediate | bool
  - cis_X_X_X_dir.stdout | trim | regex_search('^/[a-zA-Z0-9/_.-]+$') is not none
```

This prevents path injection from a malformed or tampered config file.
Apply to both AUDIT and REMEDIATE tasks that construct shell commands from
config-sourced data.

---

## Handlers

Any `lineinfile` or `replace` task that modifies an actively-used service
config must carry `notify:` to trigger a handler reload. Without `notify:` the
change takes no effect until the service restarts on its own.

Handler declaration pattern:
```yaml
- name: Resync auditd
  ansible.builtin.command: /usr/sbin/audit -s
  changed_when: false
  failed_when: false
```

Then on every `lineinfile` task targeting that config:
```yaml
notify: Resync auditd
```

---

## Lint

Target: `ansible-lint tasks/section_<N>.yml` (production profile).
Every section file must pass with 0 failures before merging. Once a section file is verified
lint-clean, add `# lint-clean: production profile` at the top to record that baseline.
Run lint before committing any change to a `tasks/` file.

**Pre-commit gate (mandatory):** Run `ansible-lint --profile production` on every touched
`tasks/` file before staging a commit or opening a PR. All lint failures must be resolved
(fix or `noqa` with justification) before the commit is made. Do not defer lint cleanup to
a follow-up commit — lint-clean state is required at every commit boundary, not just at merge.

---

## File Layout

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
