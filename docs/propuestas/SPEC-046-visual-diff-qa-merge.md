# SPEC-046: Visual Diff QA at Merge Time

**Date:** 2026-03-29
**Status:** Draft
**Depends on:** visual-quality skill, visual-qa-agent, PR Guardian, e2e-screenshot-validation rule

---

## 1. Problem

pm-workspace can analyze individual screenshots against wireframes (`/visual-qa`)
and run manual baseline comparisons (`/visual-regression`). But there is no
automated before/after visual diff triggered at merge time. A PR that passes
all functional tests can introduce subtle visual regressions (broken layouts,
shifted spacing, color drift) that only surface in production.

The gap: **no one compares what the UI looked like before the PR vs after.**

---

## 2. Architecture

### Pipeline (4 phases)

```
PR opened/updated with UI file changes detected
  |
  Phase 1 — BASELINE CAPTURE (pre-merge)
    Build main branch, run E2E suite, collect screenshots
    Store: output/visual-qa/merge-diff/{pr-id}/baseline/
  |
  Phase 2 — CANDIDATE CAPTURE (post-merge simulation)
    Build PR branch, run same E2E suite, collect screenshots
    Store: output/visual-qa/merge-diff/{pr-id}/candidate/
  |
  Phase 3 — PIXEL DIFF + SEMANTIC ANALYSIS
    For each matched screenshot pair:
      a) Pixel diff (pixelmatch or similar) → diff percentage
      b) Semantic analysis via visual-qa-agent → structural intent check
    Store: output/visual-qa/merge-diff/{pr-id}/diffs/
  |
  Phase 4 — REPORT + GATE DECISION
    Aggregate scores → visual_regression_score (0-100)
    Apply project thresholds → PASS / REVIEW / FAIL
    Post report as PR comment + output file
```

### Trigger

Activates when PR files match `visual-quality-gates.md` patterns (`*.tsx`,
`*.jsx`, `*.vue`, `*.html`, `*.css`, `*.scss`, etc.). Skips backend-only PRs.

### Screenshot Matching

Pairs by `e2e-screenshot-validation.md` naming: `{spec-name}--{test-name}.png`.
Unmatched files flagged as "new view — no baseline" (excluded from scoring).

---

## 3. Integration with PR Guardian

New optional gate: `visual_regression` (opt-in, default informational,
weight 15% of merge confidence per `visual-quality-gates.md`).

**Behavior by score:**

| Score | Action | PR Comment |
|-------|--------|------------|
| >= 90 | Auto-pass, log only | "No visual regressions detected" |
| 60-89 | Informational warning | Summary + diff thumbnails |
| < 60  | Block merge (if `blocking: true`) | Full report + action items |

The gate posts a collapsible PR comment with summary score, per-view diffs,
and link to full report. Exemption: `/visual-qa exempt [reason]` (30d expiry).

---

## 4. Threshold Configuration

Per-project in `projects/{project}/CLAUDE.md`:

| Key | Default | Description |
|-----|---------|-------------|
| `enabled` | false | Activate visual diff gate |
| `blocking` | false | Block merge on FAIL |
| `pixel_tolerance_percent` | 5 | From visual-quality-gates.md |
| `structural_tolerance_percent` | 3 | Semantic layout drift |
| `ignore_selectors` | [] | Mask dynamic content (`.timestamp`, etc.) |
| `viewports` | [375, 768, 1920] | From visual-quality-gates.md |
| `min_views_required` | 1 | Minimum matched pairs to run |
| `score_formula` | `(pixel*0.6)+(semantic*0.4)` | Weighting |

---

## 5. Storage and Privacy

Storage: `output/visual-qa/merge-diff/{pr-id}/` with subdirs `baseline/`,
`candidate/`, `diffs/`, plus `report.json` and `report.md`.

- Screenshots MUST use test/mock data — NEVER real user PII
- Mask dynamic content via `ignore_selectors` config
- Delete artifacts after 30 days. Gitignored, never committed
- Classified N4 (project data) per `context-placement-confirmation.md`
- Per-PR size budget: ~5-15MB (10 views x 3 viewports)

---

## 6. Agent Orchestration

Phase 3 uses two layers. **Pixel diff** (deterministic, no LLM): `pixelmatch`
via Node.js, ~100ms per pair. **Semantic analysis** (LLM, `visual-qa-agent`,
Sonnet, 8500 token budget): only triggered when pixel diff is 2-10%. Below 2%
is auto-pass, above 10% is auto-fail. The agent evaluates whether layout intent
is preserved despite pixel noise (font rendering, anti-aliasing, reflow).

Each view returns: `{ view, pixel_diff_pct, semantic_score, findings[] }`.
The orchestrator aggregates using the score formula from section 4.

---

## 7. Limitations

- Does NOT replace manual design review for new features
- Does NOT handle animation/video or native mobile (deferred)
- Font rendering diffs across OS are expected — semantic layer filters these
- First version: local execution only (no cloud screenshot service)

---

## 8. Rollout

| Phase | Scope | Gate Mode |
|-------|-------|-----------|
| 1 | savia-web only | Informational (non-blocking) |
| 2 | All web projects | Informational by default |
| 3 | Projects opt-in to blocking | Blocking where configured |

---

## References

- `visual-quality-gates.md` — Existing gate levels and thresholds
- `e2e-screenshot-validation.md` — Screenshot naming and storage conventions
- `visual-quality/SKILL.md` — Scoring formula and analysis checklist
- `visual-qa-agent.md` — Agent capabilities and token budget
- `/visual-regression` command — Existing baseline/test/diff/approve workflow
- PR Guardian proposal — Gate architecture and PR comment format
