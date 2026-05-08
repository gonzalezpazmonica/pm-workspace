# Spec: PR Planning Protocol — Pre-flight checklist before push/PR

**Task ID:**        WORKSPACE (no Azure DevOps task -- workspace-level feature)
**PBI padre:**      N/A -- internal tooling improvement
**Sprint:**         2026-07 (current)
**Fecha creacion:** 2026-03-27
**Creado por:**     sdd-spec-writer (Opus 4.6)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     6h
**Estado:**         Pendiente

---

## 1. Contexto y Objetivo

PRs in pm-workspace fail repeatedly at CI due to a predictable set of
causes: missing CHANGELOG entries, PII leaks in public docs, signature
hash mismatches, BATS test failures, unresolved merge conflicts, stale
documentation, and private project data leaking into public files. Each
failure wastes 10-30 minutes of re-sign, re-commit, re-push cycles.

**Objetivo:** Create the `/pr-plan` command -- a deterministic pre-flight
checklist that Savia executes BEFORE any push/PR. The command runs 10
sequential gates, stops at the first failure with actionable fix
instructions, and only proceeds to push+PR if all gates pass.

**Principio SDD:** This spec defines WHAT each gate checks and its
pass/fail criteria. The implementation decides HOW to orchestrate the
checks (bash script vs command .md + inline logic).

---

## 2. Contrato Tecnico

### 2.1 Command interface

```markdown
# File: .opencode/commands/pr-plan.md
# Invocation: /pr-plan [--dry-run] [--skip-push] [--title "PR title"]
# Arguments:
#   --dry-run     Run all gates, report results, do NOT push or create PR
#   --skip-push   Run all gates, sign, but do NOT push or create PR
#   --title "T"   Override auto-generated PR title
```

### 2.2 Gate definitions (sequential, stop-on-fail)

| Gate | Name | Script/Check | Pass criteria | Fail action |
|------|------|-------------|---------------|-------------|
| G1 | Branch safety | `git rev-parse --abbrev-ref HEAD` | Not `main` or `master` | STOP: "Switch to feature branch" |
| G2 | Clean working tree | `git status --porcelain` | Empty output (no uncommitted changes) | STOP: "Commit or stash changes first" |
| G3 | No merge conflicts | `grep -rn 'CONFLICT-MARKER' on tracked files` | Zero matches | STOP: "Resolve merge conflicts in {files}" |
| G4 | Divergence check | `git fetch origin main && git merge-base --is-ancestor origin/main HEAD` | HEAD contains all of origin/main | STOP: "Rebase onto main: git rebase origin/main" |
| G5 | CHANGELOG audit | See section 2.3 | Entry exists if high-impact files changed | STOP: "Add CHANGELOG entry" + auto-generate draft |
| G6 | BATS tests | `bash tests/run-all.sh` | Exit code 0 | STOP: "Fix failing tests: {suite names}" |
| G7 | Confidentiality scan | `bash scripts/confidentiality-scan.sh --pr` | Exit code 0 (no violations) | STOP: "Fix violations: {list}" |
| G8 | Documentation check | See section 2.4 | Docs updated for new components | WARN: "Consider updating {files}" (non-blocking) |
| G9 | Zero project leakage | See section 2.5 | No private data in public docs | STOP: "Remove private data from {files}" |
| G10 | CI validation | `bash scripts/validate-ci-local.sh` | Output contains "safe to push" | STOP: "Fix CI issues: {errors}" |

After all gates pass, execution continues to:

| Step | Name | Action |
|------|------|--------|
| S1 | Sign | `bash scripts/confidentiality-sign.sh sign` |
| S2 | Commit signature | `git add .confidentiality-signature && git commit -m "chore: sign confidentiality audit"` (only if changed) |
| S3 | Push | `git push origin {branch}` |
| S4 | Create PR | Use `push-pr.sh` logic or `gh pr create` |

If `--dry-run` is active, skip S1-S4 and print the report only.
If `--skip-push` is active, execute S1-S2 and stop.

### 2.3 Gate G5 -- CHANGELOG audit logic

**High-impact file patterns** (changes to these require a CHANGELOG entry):

```
docs/rules/**
.opencode/hooks/**
.opencode/agents/**
.opencode/skills/**
.claude/settings.json
scripts/**
docs/**
CLAUDE.md
```

**Algorithm:**

1. Get list of changed files: `git diff origin/main..HEAD --name-only`
2. Check if any match high-impact patterns above
3. If yes: parse `CHANGELOG.md` for the highest version `## [X.Y.Z]`
4. Parse `origin/main:CHANGELOG.md` for highest version on main
5. If versions are identical --> FAIL (no new entry)
6. If local version > main version --> PASS
7. On FAIL: auto-generate a draft CHANGELOG entry:
   - Scan changed files to classify: Added/Changed/Fixed/Removed
   - Propose next version (minor bump if new features, patch if fixes)
   - Print the draft to console for the user to copy
   - Print: "Add this entry to CHANGELOG.md, commit, then re-run /pr-plan"

### 2.4 Gate G8 -- Documentation check logic

**Detection rules:**

| Change detected | Expected doc update |
|----------------|-------------------|
| New file in `.opencode/commands/` | `README.md` command table updated |
| New file in `.opencode/skills/` | `README.md` skills table updated |
| New file in `.opencode/agents/` | `README.md` agents table updated |
| New file in `docs/rules/` | No README needed (rules are internal) |
| New file in `scripts/` | `README.md` scripts section if user-facing |

**Algorithm:**

1. Get list of NEW files (not modified): `git diff origin/main..HEAD --diff-filter=A --name-only`
2. Check if any match the patterns above
3. If yes: check if `README.md` is also in the changed files list
4. If `README.md` is not changed --> WARN (not blocking, just advisory)
5. Print: "New {type} added but README.md not updated. Consider running readme update."

### 2.5 Gate G9 -- Zero project leakage logic

**Scan targets:** All files in the diff that are NOT gitignored (public files).

**Patterns to detect:**

1. Real project names from `projects/` directory:
   ```bash
   ls -d projects/*/ 2>/dev/null | xargs -I{} basename {} | \
     grep -v '^_' | grep -v '^team-'
   ```
   Search these names in all public changed files.

2. Patterns from `CLAUDE.local.md` if it exists:
   - Organization URLs (dev.azure.com/REAL-ORG)
   - Real email addresses
   - Real team names

3. Content from `projects/*/` paths referenced in public files.

4. Hardcoded PII patterns (reuse regex from `confidentiality-scan.sh`):
   - `dev.azure.com/` followed by something other than `MI-ORGANIZACION`
   - Real GitHub handles (not `your-handle` or `your-org`)

**Algorithm:**

1. Get list of public changed files (exclude gitignored, exclude `projects/`)
2. Build blocklist: project directory names + CLAUDE.local.md patterns
3. For each public file in diff, search for blocklist terms
4. If any match --> FAIL with file:line:match details
5. Print: "Remove private data: {file}:{line} contains '{match}'"

---

## 3. Inputs / Outputs Contract

### Inputs

```
Arguments (all optional):
  --dry-run:   boolean (default: false)
  --skip-push: boolean (default: false)
  --title:     string  (default: auto-generated from first commit message)
```

### Outputs

**Console output (always):** Pre-flight report with pass/fail per gate.

```
------------------------------------------------------------
  PR Pre-Flight — {branch}
------------------------------------------------------------

  G1  Branch safety ............... PASS (feature/my-branch)
  G2  Clean working tree .......... PASS
  G3  No merge conflicts .......... PASS
  G4  Divergence from main ........ PASS (0 commits behind)
  G5  CHANGELOG audit ............. PASS (v3.69.0)
  G6  BATS tests .................. PASS (12/12 suites)
  G7  Confidentiality scan ........ PASS (0 violations)
  G8  Documentation check ......... WARN (new command, README not updated)
  G9  Zero project leakage ........ PASS
  G10 CI validation ............... PASS

------------------------------------------------------------
  Result: 9 PASS | 0 FAIL | 1 WARN
------------------------------------------------------------

  Signing... done.
  Pushing... done.
  PR created: https://github.com/org/repo/pull/NNN

------------------------------------------------------------
```

**On failure (stop at first FAIL):**

```
------------------------------------------------------------
  PR Pre-Flight — {branch}
------------------------------------------------------------

  G1  Branch safety ............... PASS (feature/my-branch)
  G2  Clean working tree .......... PASS
  G3  No merge conflicts .......... PASS
  G4  Divergence from main ........ PASS
  G5  CHANGELOG audit ............. FAIL

------------------------------------------------------------
  STOPPED at G5: CHANGELOG not updated
------------------------------------------------------------

  High-impact files changed:
    docs/rules/domain/new-rule.md (Added)
    scripts/new-script.sh (Added)

  Suggested CHANGELOG entry (copy to CHANGELOG.md):

  ## [3.69.0] — 2026-03-27

  PR planning protocol and new rule.

  ### Added
  - **Rule**: new-rule.md — description
  - **Script**: new-script.sh — description

  After adding the entry, commit and re-run: /pr-plan

------------------------------------------------------------
```

### Side effects

| Effect | When |
|--------|------|
| `git fetch origin main` | Always (G4 divergence check) |
| `.confidentiality-signature` file updated | After all gates pass (S1) |
| New commit for signature | After S1 if signature changed (S2) |
| `git push` | After S2 unless `--dry-run` or `--skip-push` |
| PR created on GitHub | After push unless `--dry-run` or `--skip-push` |

---

## 4. Reglas de Negocio

| # | Regla | Error/Action | Gate |
|---|-------|-------------|------|
| RN-01 | Gates execute sequentially in order G1-G10; stop at first FAIL | Print report up to failure point | All |
| RN-02 | WARNs (G8) do not stop execution; they appear in the report but allow proceeding | Print advisory, continue | G8 |
| RN-03 | Signature (S1) MUST be the last content-modifying step before push, per `pr-signing-protocol.md` | Sign only after all gates pass | S1 |
| RN-04 | If `--dry-run`, never modify any file or execute push/PR | Report only, exit 0 on all-pass or exit 1 on fail | All |
| RN-05 | CHANGELOG is required only when high-impact files changed (section 2.3 patterns) | Skip G5 silently if no high-impact files in diff | G5 |
| RN-06 | Merge conflict detection scans ALL tracked files, not just the diff | `grep -rn` across repo, exclude `.git/` and binary files | G3 |
| RN-07 | The command MUST NOT create any commits except the signature commit (S2) | User must commit CHANGELOG and fixes manually | S2 |
| RN-08 | Exit code 0 if all gates pass (and push succeeds); exit code 1 if any gate fails | Standard unix exit codes | All |
| RN-09 | The `--title` flag is passed to `push-pr.sh` as `--title` argument | Forwarded verbatim | S4 |
| RN-10 | If `bats` is not installed, G6 prints a WARN and skips (degraded mode) | "bats not found, skipping tests" | G6 |

---

## 5. Constraints and Limits

### Performance

| Metric | Limit | Note |
|--------|-------|------|
| Total execution time (gates only) | < 120s | BATS is the bottleneck (~30-60s) |
| Git fetch timeout | 30s | Network dependent |

### Compatibility

| Element | Constraint |
|---------|-----------|
| Shell | bash 4+ (Git Bash on Windows, native on Linux/macOS) |
| Dependencies | git, bash, grep, sed, awk (standard unix) |
| Optional deps | bats (for G6), python3 (for push-pr.sh PR creation) |
| OS | Windows (Git Bash), Linux, macOS |

### Security

| Aspect | Requirement |
|--------|------------|
| No credentials in output | Gate reports never print matched credential values, only file:line |
| No PII in CHANGELOG draft | Auto-generated CHANGELOG uses generic descriptions |

---

## 6. Test Scenarios

### Happy Path

```
Scenario: All gates pass, PR created
  Given branch "feature/new-rule" with 3 commits ahead of main
  And CHANGELOG.md updated with new version
  And all BATS tests pass
  And no confidentiality violations
  And no merge conflicts
  And no private data in public files
  When /pr-plan is executed
  Then G1-G10 all show PASS
  And signature is created
  And push succeeds
  And PR URL is printed
  And exit code is 0
```

### Failure Cases

```
Scenario: CHANGELOG missing when rules changed
  Given branch "feature/add-rule" with changes to docs/rules/domain/foo.md
  And CHANGELOG.md has same version as origin/main
  When /pr-plan is executed
  Then G1-G4 show PASS
  And G5 shows FAIL
  And output includes "CHANGELOG not updated"
  And output includes a suggested CHANGELOG entry with "Added" section
  And exit code is 1
  And no push or PR is created

Scenario: Merge conflict markers in file
  Given a file src/foo.sh containing "CONFLICT-MARKER HEAD"
  When /pr-plan is executed
  Then G1-G2 show PASS
  And G3 shows FAIL
  And output includes the filename with conflict markers
  And exit code is 1

Scenario: Private project name in README
  Given projects/acme-client/ exists (real project directory)
  And README.md contains the string "acme-client"
  When /pr-plan is executed
  Then G1-G8 show PASS (or applicable gates pass)
  And G9 shows FAIL
  And output includes "README.md:{line} contains 'acme-client'"
  And exit code is 1

Scenario: BATS test failure
  Given one BATS suite has a failing test
  When /pr-plan is executed
  Then G1-G5 show PASS
  And G6 shows FAIL
  And output includes the name of the failing suite
  And exit code is 1

Scenario: Uncommitted changes present
  Given tracked file modified but not committed
  When /pr-plan is executed
  Then G1 shows PASS
  And G2 shows FAIL
  And output includes "Commit or stash changes first"
  And exit code is 1
```

### Edge Cases

```
Scenario: No high-impact files changed (CHANGELOG not required)
  Given only projects/savia-web/src/foo.vue changed
  And CHANGELOG.md not updated
  When /pr-plan is executed
  Then G5 shows PASS (skipped -- no high-impact files)
  And remaining gates proceed normally

Scenario: --dry-run prevents push
  Given all gates pass
  When /pr-plan --dry-run is executed
  Then report shows all PASS
  And no signature is created
  And no push occurs
  And no PR is created
  And exit code is 0

Scenario: --skip-push signs but does not push
  Given all gates pass
  When /pr-plan --skip-push is executed
  Then report shows all PASS
  And signature IS created
  And no push occurs
  And no PR is created

Scenario: bats not installed
  Given bats command not found in PATH
  When /pr-plan is executed
  Then G6 shows WARN ("bats not installed, skipping")
  And execution continues to G7

Scenario: Branch is main
  Given current branch is "main"
  When /pr-plan is executed
  Then G1 shows FAIL
  And output includes "Switch to feature branch"
  And exit code is 1
  And no further gates execute
```

---

## 7. Ficheros a Crear / Modificar

### Crear (nuevos)

```
.opencode/commands/pr-plan.md              # Slash command definition (frontmatter + instructions)
scripts/pr-plan.sh                       # Main orchestration script (gates G1-G10 + S1-S4)
```

### Modificar (existentes)

```
# None -- this is additive. push-pr.sh is CALLED, not modified.
```

### NO tocar

```
scripts/push-pr.sh                       # Called as-is for S3-S4
scripts/confidentiality-sign.sh          # Called as-is for S1
scripts/confidentiality-scan.sh          # Called as-is for G7
scripts/validate-ci-local.sh             # Called as-is for G10
tests/run-all.sh                         # Called as-is for G6
CHANGELOG.md                             # User modifies manually; command only suggests
```

---

## 8. Configuracion de Entorno

```bash
# Project
PROJECT_DIR="$(pwd)"   # pm-workspace root

# Dependencies (all must be in PATH)
# Required: git, bash, grep, sed, awk
# Optional: bats (for G6), python3 (for push-pr.sh)

# Verification commands
bash scripts/pr-plan.sh --dry-run        # Full pre-flight without push
bash scripts/pr-plan.sh                  # Full pre-flight + push + PR
bash scripts/pr-plan.sh --skip-push      # Pre-flight + sign only
```

---

## 9. Estado de Implementacion

```
**Estado:** Pendiente
**Ultimo update:** 2026-03-27
**Actualizado por:** sdd-spec-writer
```

---

## 10. Checklist Pre-Entrega

```markdown
### Implementacion
- [ ] .opencode/commands/pr-plan.md created with frontmatter (name, description, allowed-tools, model)
- [ ] scripts/pr-plan.sh created with all 10 gates
- [ ] Gates execute sequentially, stop at first FAIL
- [ ] --dry-run flag prevents any file modification or push
- [ ] --skip-push flag signs but does not push
- [ ] --title flag forwarded to push-pr.sh
- [ ] CHANGELOG draft auto-generation works (classifies Added/Changed/Fixed/Removed)
- [ ] Zero project leakage scan builds blocklist from projects/ directory names
- [ ] Report format matches section 3 output examples
- [ ] Exit code 0 on success, 1 on failure
- [ ] Script is < 150 lines (if exceeding, split into helper functions)
- [ ] bats-not-installed degradation works (WARN, not FAIL)

### Integration
- [ ] /pr-plan can be invoked as slash command in Claude Code
- [ ] scripts/pr-plan.sh can be invoked standalone from terminal
- [ ] Does not conflict with existing push-pr.sh (calls it, does not replace it)
```

---

## 11. Notas para el Revisor

1. **Relationship to push-pr.sh**: `/pr-plan` is a SUPERSET of `push-pr.sh`.
   It adds gates G1-G9 before the existing push-pr flow. Long term,
   `push-pr.sh` could be refactored to call `pr-plan.sh`, but for now
   they coexist. `pr-plan.sh` calls `push-pr.sh` for S3-S4, or
   reimplements the push+PR step inline if simpler.

2. **Gate ordering rationale**: Fast checks first (branch, clean tree,
   conflicts, divergence), then content checks (CHANGELOG, tests, scan),
   then meta-checks (docs, leakage, CI). This minimizes wasted time --
   a 60s BATS run only happens after instant checks pass.

3. **G5 auto-generation is advisory only**: The command prints a draft
   CHANGELOG entry but NEVER writes to CHANGELOG.md. The user must
   copy, edit if needed, commit, and re-run. This respects RN-07.

4. **G8 is non-blocking by design**: Documentation updates are valuable
   but should not block urgent fixes. The WARN ensures visibility
   without creating friction.

5. **References to existing rules**:
   - `pr-signing-protocol.md` -- signing order (sign LAST)
   - `changelog-enforcement.md` -- CHANGELOG requirements
   - `pii-sanitization.md` -- PII patterns
   - `project-privacy-protection.md` -- project leakage prevention
   - `pre-commit-bats.md` -- BATS before commit
   - `command-ux-feedback.md` -- banner and progress format

---

## 12. Iteration and Convergence Criteria

### Spec is ready for implementation when:

- [x] All 10 gates defined with exact pass/fail criteria
- [x] Input/output types concrete (CLI flags, console format)
- [x] Business rules enumerated with ID, description, gate reference
- [x] Test scenarios cover happy path + 5 failure cases + 4 edge cases
- [x] Files to create/modify listed with exact paths
- [x] Existing scripts referenced, not reimplemented
- [x] Auto-generated CHANGELOG draft format specified
- [x] Report format specified with concrete examples

### NOT ready if:

- Any gate has "TBD" pass criteria
- Any scenario uses "valid input" instead of concrete data
- File paths are relative or incomplete
