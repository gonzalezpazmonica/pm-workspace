---
spec_id: SE-092
date: 2026-06-24
type: feat
scope: mvp
---

# SE-092 MVP — Bridge Azure DevOps/Jira detection layer

## Summary

Implements the SE-092 MVP detection layer: pm-backend-health.sh and
pm-backend-query.py. Bridges Savia commands to real PM backends.

## Changes

### New scripts

**`scripts/pm-backend-health.sh`**
- Detects ADO vs Jira vs none backend configuration
- Reads from pm-config.local.md and env vars
- Output: JSON {backend, configured, pat_file_exists, project, org, notes}
- Always exit 0 (no secrets exposed)
- NEVER reads PAT content — only checks file existence

**`scripts/pm-backend-query.py`**
- CLI for PM queries: --sprint-status, --my-items
- With ADO backend: queries via REST API (PAT via file/env, never hardcoded)
- Without backend: returns mock data with "backend not configured" note
- --json flag for machine-consumable output
- --mock flag to force mock mode

### Tests

- `tests/scripts/test_pm_backend.py` — 7 pytest tests, all passing:
  1. health-check produces valid JSON
  2. query with no backend returns mock data
  3. PAT never appears in any output
  4. sprint-status produces items array
  5. my-items produces items array
  6. health-check with ADO config returns configured=True
  7. --json flag produces parseable JSON

## Out of scope (full SE-092)

Remaining slices (ado-bridge.sh, /sprint-status command, /board-flow, etc.)
are in SE-092 full implementation scope (~60 min additional).
