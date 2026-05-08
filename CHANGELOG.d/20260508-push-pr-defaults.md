## fix(push-pr): safer defaults — draft + smarter title selection

### Changed
- `scripts/push-pr.sh` now creates PRs as **draft by default** (was: ready-for-review). Use `--no-draft` to opt out. Backward-compat: `--draft` flag preserved as no-op.
- Title auto-selection now prefers the **first** `feat:`/`fix:` commit in chronological order on the branch, falling back to the previous behavior (first non-chore/non-Merge in descending log) only if no conventional-commit feat/fix is found.

### Why
- **Draft default**: matches autonomous-safety pattern — PRs created via `/pr-plan` should require explicit human action to become reviewable. Avoids accidental ready-for-review on autonomous flows.
- **Title selection**: previous logic picked the *latest* commit (e.g. drift fixes like `fix(ci): ...`), masking the actual feature intent. Real example: PR #3 `fix(tool-healing): ...` was titled with the trailing `fix(ci)` drift commit and required manual PATCH via REST API to correct.

### Compatibility
- Existing `--draft` callers: unchanged behavior.
- Callers that relied on default ready-for-review: must add `--no-draft`.
