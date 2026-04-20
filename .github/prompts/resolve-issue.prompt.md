---
agent: agent
description: Resolve a GitHub issue in the FreeBSD 14 CIS Ansible role — read the issue, implement the fix on a dedicated branch, pass pre-commit gates, open a PR, and close the loop.
---

Follow these steps exactly.

## 1. Read the issue

- Fetch the issue with `github-pull-request_issue_fetch` (issueNumber, owner: vrwmiller, repo: ansible_freebsd_14_cis_benchmarks_v1_0_1).
- Extract: title, body, any inline code blocks, referenced file paths and line numbers.
- If the issue references a specific file and line, read that file at `[line - 20, line + 60]` to capture full context before proceeding.

## 2. Load authoritative context

Read the following before writing any code:

- `.github/copilot-instructions.md` — project conventions, lint rules, control block structure
- `.github/instructions/security.instructions.md` — security requirements
- `docs/DESIGN.md` — canonical patterns and rationale
- Any `tasks/section_N.yml` file touched by the proposed change (read in full for the relevant section)
- `defaults/main.yml` — to understand operator-tunable variables involved

## 3. Branch

Create a branch following the naming convention:

- `fix/<topic>` for bugs and security findings
- `feat/<topic>` for new controls or features
- `chore/<topic>` for housekeeping

Never commit directly to `main`.

```
git checkout -b fix/<topic>
```

## 4. Implement the fix

Apply the minimum change that resolves the issue without over-engineering.

### Security input-validation pattern (when fixing injection / format validation issues)

When a role variable is interpolated into a shell command or config file, add a `regex_search` guard:

```yaml
- name: "<id> | REMEDIATE | <action>"
  <module>:
    ...
  when:
    - freebsd_cis_remediate | bool
    - <existing compliance conditions>
    - some_variable | regex_search('^[safe_pattern]+$') is not none
```

Pair it with a validation-failure warning task:

```yaml
- name: "<id> | REMEDIATE | Warn — <variable> failed format validation"
  ansible.builtin.debug:
    msg: >-
      REMEDIATION SKIPPED: <variable> value '{{ <variable> }}'
      failed format validation. Value must match '<pattern>' to prevent
      <config file> injection. This may indicate inventory tampering or operator error.
  when:
    - freebsd_cis_remediate | bool
    - <existing conditions except the passing regex guard>
    - some_variable | regex_search('^[safe_pattern]+$') is none
```

Key rules:
- `regex_search()` in `when:` must always end with `is not none` (truthy branch) or `is none` (falsy/warning branch). A bare string result causes `Conditional result was derived from value of type 'str'`.
- Insert the validation `when:` condition after all existing conditions so existing gates still fire first.
- Do NOT use `|| true` in shell/command remediation tasks — use `failed_when: false` instead.
- Use raw audit signals (`.rc`, `.stdout`) as remediation gates, never `result is changed`.

### Other common fix patterns

See `docs/DESIGN.md` and `.github/copilot-instructions.md` for:
- Optional-file audits (false-COMPLIANT prevention via `stat` pre-flight)
- Optional-binary pre-flights
- POSIX grep portability (`[[:space:]]` not `\s` in `ansible.builtin.command`)
- Python `re` in `ansible.builtin.replace` (`\s` OK, `[[:space:]]` not recognized)

## 5. Commit

Stage only the touched files, then commit. Pre-commit hooks run automatically and cover:
- `detect-secrets`
- `ansible-syntax-check`
- `ansible-lint --profile production` (via `scripts/lint-check.sh`)

Do **not** run ansible-lint manually before committing — the pre-commit hook handles it. If the commit fails due to a lint error, fix the error and retry.

Commit message format:

```
fix: <imperative summary under 72 chars>

<Body: what changed and why, one paragraph.>

Fixes #<issue-number>.
```

## 6. Push and open PR

```
git push --set-upstream origin <branch>
```

Then call `github-pull-request_create_pull_request` with:

- **title**: `fix: <same as commit summary>`
- **head**: branch name (no `owner:` prefix)
- **base**: omit (defaults to `main`)
- **body**: include Summary, Why, Changes (file-by-file), Validation, Risks and Follow-ups sections. Reference `Fixes #<issue-number>.`

## 7. Validation checklist before opening PR

- [ ] Pre-commit hooks passed (detect-secrets, syntax-check, ansible-lint)
- [ ] No `|| true` in REMEDIATE shell/command tasks
- [ ] Every `regex_search()` in `when:` ends with `is not none` or `is none`
- [ ] Paired warning task present if a validation guard was added
- [ ] Fix is minimum viable — no unrequested refactors or cosmetic changes

## 8. Post-PR

After the PR is created, Copilot review is triggered automatically. Do not manually request it on creation.

If follow-up commits are made after review, trigger a new Copilot pass with:

```
gh pr edit <number> --add-reviewer @copilot
```
