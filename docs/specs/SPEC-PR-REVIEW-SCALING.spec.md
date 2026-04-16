# Spec: PR Review Depth Scaling -- Size-driven review escalation

**Task ID:**        WORKSPACE (no Azure DevOps task -- workspace-level feature)
**PBI padre:**      N/A -- internal tooling improvement
**Sprint:**         2026-07 (current)
**Fecha creacion:** 2026-03-27
**Creado por:**     sdd-spec-writer (Opus 4.6)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     4h
**Estado:**         Pendiente

---

## 1. Contexto y Objetivo

pm-workspace has two related but disconnected systems for PR review:
`risk-escalation.md` defines four tiers (Low/Medium/High/Critical) based on
a risk score (0-100), and `scoring-curves.md` defines a PR Size curve that
maps lines changed to a 0-100 score. Neither system is wired into the
`pr-plan.sh` pre-flight pipeline, so every PR gets the same review
treatment regardless of whether it changes 10 lines or 1500.

The Claude Blog on code review (2025) demonstrates that review depth should
scale with PR size: tiny diffs need only automated lint, medium diffs need
a standard reviewer, large diffs need multiple reviewers, and huge diffs
need a full consensus panel. This matches `risk-escalation.md` tiers but
adds PR size as a first-class input.

**Objetivo:** Add gate G11 ("Review depth scaling") to `pr-plan-gates.sh`
that calculates the total lines changed in the PR, determines the review
depth tier, logs the recommendation, and integrates with the existing
risk-escalation thresholds. The gate never blocks -- it emits a WARN with
the recommended review level.

**Principio SDD:** This spec defines WHAT G11 checks, what tiers exist,
how PR size maps to review depth, and the output format. The agent decides
HOW to implement the bash logic.

---

## 2. Contrato Tecnico

### 2.1 New gate function: g11

**File:** `scripts/pr-plan-gates.sh`
**Position:** After g10, appended at end of file.

```bash
# Signature:
g11()
# Returns via stdout:
#   "WARN: Review level: {LEVEL} ({N} lines) -- {recommendation}"
#   or plain text for PASS (informational)
# Never returns "FAIL:" -- this gate is advisory only.
```

### 2.2 Gate registration in pr-plan.sh

**File:** `scripts/pr-plan.sh`
**Change:** Add one line after the `gate "G10"` call:

```bash
gate "G11" "Review depth scaling" g11
```

### 2.3 PR size calculation

The function calculates lines changed between `origin/main` and `HEAD`:

```bash
git diff origin/main..HEAD --stat | tail -1
# Parse: "X files changed, Y insertions(+), Z deletions(-)"
# PR_SIZE = Y + Z (total insertions + deletions)
```

### 2.4 Tier mapping (piecewise, aligned with scoring-curves.md)

| PR Size (lines) | Tier | Score | Review Depth | Recommendation |
|---|---|---|---|---|
| < 50 | XS | 100 | Quick lint | "Automated checks sufficient" |
| 50-300 | S/M | 65-85 | Standard | "Standard code-reviewer (1 reviewer)" |
| 301-1000 | L | 10-35 | Enhanced | "Enhanced review (2 reviewers + architect)" |
| > 1000 | XL+ | 0-10 | Full consensus | "Full consensus panel (2 reviewers + architect + security)" |

Breakpoints (for piecewise linear interpolation of score):

```
Lines    Score
0        100
50       100
100       85
250       65
500       35
1000      10
2000       0
```

These breakpoints are identical to `scoring-curves.md` "PR Size" curve.

### 2.5 Risk score integration

If a risk-scoring output file exists at `output/risk-score.json` with
field `score` (0-100), the gate reads it and adjusts:

```
effective_tier = max_severity(size_tier, risk_tier)
```

Where `risk_tier` maps from `risk-escalation.md`:
- score 0-25 -> Quick lint
- score 26-50 -> Standard
- score 51-75 -> Enhanced
- score 76-100 -> Full consensus

If the risk file does not exist, the gate uses size_tier alone.

### 2.6 Output format

**For XS PRs (< 50 lines):**
```
XS (23 lines) — quick lint
```
This is informational (PASS), not a WARN.

**For S/M PRs (50-300 lines):**
```
WARN: Review level: STANDARD (187 lines) — 1 reviewer recommended
```

**For L PRs (301-1000 lines):**
```
WARN: Review level: ENHANCED (542 lines) — 2 reviewers + architect recommended
```

**For XL+ PRs (> 1000 lines):**
```
WARN: Review level: FULL (1847 lines) — consensus panel recommended. Consider splitting.
```

If risk score escalated the tier:
```
WARN: Review level: ENHANCED (187 lines, risk score 62 escalated from STANDARD) — 2 reviewers + architect recommended
```

---

## 3. Reglas de Negocio

| # | Regla | Efecto |
|---|---|---|
| RN-01 | G11 NEVER emits "FAIL:" -- it is advisory only | Gate does not block push/PR |
| RN-02 | PR size = insertions + deletions from `git diff --stat` | Consistent with scoring-curves.md definition |
| RN-03 | If `origin/main` is unreachable (no fetch), default to 0 lines and WARN | Graceful degradation |
| RN-04 | If PR has 0 lines changed (empty diff), output "0 lines — nothing to review" as PASS | Edge case: signature-only commits |
| RN-05 | Risk score file is optional; if missing or unparseable, ignore silently | No hard dependency on risk-scoring skill |
| RN-06 | Tier escalation is one-way: risk can escalate tier UP, never down | `max_severity()` semantics |
| RN-07 | Lines in binary files (images, fonts) are excluded from count | `--stat` does not count binary content |
| RN-08 | The score field is computed but only logged, not used to block | Future use by PR Guardian |

---

## 4. Constraints

### Performance
| Metrica | Limite |
|---|---|
| Gate execution time | < 2s (git diff --stat is fast) |
| No network calls | Only reads local git state + optional local file |

### Compatibility
| Elemento | Constraint |
|---|---|
| Shell | Bash 4+ (Git Bash on Windows, native on Linux/macOS) |
| Git | 2.20+ (supports --stat formatting used) |
| Dependencies | None beyond git + standard Unix tools (grep, sed, awk, tail) |

### Security
| Aspecto | Requirement |
|---|---|
| No secrets | Gate reads no credentials, only git diff output |
| No network | No API calls, no HTTP requests |

---

## 5. Test Scenarios

### Happy Path

```
Scenario: Small PR with 23 lines
  Given branch has 23 lines changed vs origin/main
  And no risk-score.json exists
  When g11 runs
  Then output is "XS (23 lines) — quick lint"
  And exit code is 0 (PASS in gate framework)

Scenario: Medium PR with 187 lines
  Given branch has 187 lines changed
  And no risk-score.json exists
  When g11 runs
  Then output starts with "WARN: Review level: STANDARD (187 lines)"

Scenario: Large PR with 542 lines
  Given branch has 542 lines changed
  And no risk-score.json exists
  When g11 runs
  Then output starts with "WARN: Review level: ENHANCED (542 lines)"

Scenario: XL PR with 1847 lines
  Given branch has 1847 lines changed
  When g11 runs
  Then output contains "FULL (1847 lines)"
  And output contains "Consider splitting"
```

### Risk Score Integration

```
Scenario: Medium PR escalated by high risk score
  Given branch has 187 lines changed (normally STANDARD)
  And output/risk-score.json exists with {"score": 62}
  When g11 runs
  Then output contains "ENHANCED"
  And output contains "risk score 62 escalated from STANDARD"

Scenario: Risk score file missing
  Given branch has 542 lines changed
  And output/risk-score.json does not exist
  When g11 runs
  Then output contains "ENHANCED (542 lines)"
  And no mention of risk score

Scenario: Risk score file malformed
  Given output/risk-score.json contains "not json"
  When g11 runs
  Then risk score is ignored silently
  And tier is determined by size alone
```

### Edge Cases

```
Scenario: Empty diff (0 lines)
  Given branch has 0 lines changed vs origin/main
  When g11 runs
  Then output is "0 lines — nothing to review"
  And exit code is 0 (PASS)

Scenario: Exactly 50 lines (boundary)
  Given branch has exactly 50 lines changed
  When g11 runs
  Then output contains "STANDARD" (50 is the lower bound of S tier)

Scenario: Exactly 300 lines (boundary)
  Given branch has exactly 300 lines changed
  When g11 runs
  Then output contains "STANDARD" (300 is the upper bound of S/M tier)

Scenario: Exactly 301 lines (boundary)
  Given branch has exactly 301 lines changed
  When g11 runs
  Then output contains "ENHANCED"

Scenario: Exactly 1000 lines (boundary)
  Given branch has exactly 1000 lines changed
  When g11 runs
  Then output contains "ENHANCED" (1000 is upper bound of L tier)

Scenario: 1001 lines (boundary)
  Given branch has 1001 lines changed
  When g11 runs
  Then output contains "FULL"

Scenario: origin/main unreachable
  Given git fetch origin main fails
  When g11 runs
  Then output is "WARN: Review level: unknown (origin/main unreachable)"

Scenario: Risk score cannot escalate DOWN
  Given branch has 1500 lines changed (FULL tier)
  And output/risk-score.json exists with {"score": 10} (Low risk)
  When g11 runs
  Then output contains "FULL" (not downgraded to Quick lint)
```

---

## 6. Ficheros a Crear / Modificar

### Modificar (existentes)

```
scripts/pr-plan-gates.sh   # Append function g11() at end of file (~25-35 lines)
scripts/pr-plan.sh         # Add gate "G11" "Review depth scaling" g11 line after G10
```

### Crear (nuevos)

```
tests/test-pr-review-scaling.bats  # BATS test file for g11 function (~60-80 lines)
```

### NO tocar

```
docs/rules/domain/risk-escalation.md     # Reference only, do not modify
docs/rules/domain/scoring-curves.md       # Reference only, do not modify
scripts/confidentiality-sign.sh              # Unrelated
scripts/push-pr.sh                           # Unrelated
```

---

## 7. Codigo de Referencia

### Gate function pattern (from pr-plan-gates.sh):

```bash
# Reference: g5 (CHANGELOG audit) -- similar pattern of reading git diff
# and emitting PASS/WARN/FAIL
g5() {
  local all; all=$(git diff origin/main..HEAD --name-only 2>/dev/null) || true
  # ... analysis logic ...
  echo "v$lv"  # PASS with info
}
```

### BATS test pattern:

```bash
# Reference: tests/test-changelog-integrity.bats or similar BATS file
@test "g11 returns XS for small PR" {
  # Setup: mock git diff --stat output
  # Run: source pr-plan-gates.sh; g11
  # Assert: output contains expected text
}
```

### git diff --stat output format:

```
 scripts/pr-plan-gates.sh | 35 +++++++++++++++++++++++
 scripts/pr-plan.sh       |  1 +
 2 files changed, 36 insertions(+), 0 deletions(-)
```

The last line is parsed: extract numbers after "insertions" and "deletions".

---

## 8. Configuracion de Entorno

```bash
# Project
PROJECT_DIR="."
# No solution file -- this is bash, not .NET

# Verification commands
bash tests/test-pr-review-scaling.bats          # BATS tests for g11
bash scripts/pr-plan.sh --dry-run               # Full pre-flight including G11
```

**Variables de entorno necesarias:**
```
# None -- g11 reads only local git state
# Optional: output/risk-score.json (created by risk-scoring skill, if available)
```

---

## 9. Estado de Implementacion

**Estado:** Pendiente

**Ultimo update:** 2026-03-27
**Actualizado por:** sdd-spec-writer

---

## 10. Checklist Pre-Entrega

### Implementacion
- [ ] g11() function appended to scripts/pr-plan-gates.sh
- [ ] gate "G11" line added to scripts/pr-plan.sh after G10
- [ ] g11 correctly parses `git diff origin/main..HEAD --stat` output
- [ ] Tier mapping matches section 2.4 breakpoints exactly
- [ ] Risk score integration reads output/risk-score.json if present
- [ ] g11 never emits "FAIL:" (advisory only, RN-01)
- [ ] Edge case: 0 lines handled (RN-04)
- [ ] Edge case: origin/main unreachable handled (RN-03)
- [ ] BATS tests created in tests/test-pr-review-scaling.bats
- [ ] All 13 test scenarios from section 5 have corresponding BATS tests
- [ ] `bash scripts/pr-plan.sh --dry-run` runs successfully with G11 included
- [ ] No existing gates (G0-G10) are modified or broken

### Especifico para agente
- [ ] No files created outside of section 6 list
- [ ] No decisions taken outside this spec
- [ ] Output format matches section 2.6 exactly
- [ ] Boundary values (50, 300, 301, 1000, 1001) tested

---

## 11. Notas para el Revisor

1. G11 is intentionally WARN-only, not FAIL. The goal is to surface the
   recommendation in the pre-flight output so the developer knows what
   review level to request. Blocking on PR size would be too aggressive
   for a workspace that sometimes needs large coordinated changes.

2. The tier breakpoints are intentionally aligned with `scoring-curves.md`
   PR Size curve. If that curve is updated, G11 breakpoints should be
   updated to match.

3. Risk score integration is optional and forward-looking. The
   `output/risk-score.json` file does not exist today in most flows.
   When a risk-scoring skill is implemented, it will write this file
   and G11 will automatically pick it up.

4. The "Consider splitting" message for XL+ PRs is inspired by the
   Claude Blog recommendation that PRs over 1000 lines should be split
   into smaller, reviewable units.

5. Boundary at 50 lines: PRs with exactly 50 lines are classified as
   STANDARD (not XS). This is a deliberate choice -- 50 lines is enough
   to introduce a meaningful bug that warrants human review.
