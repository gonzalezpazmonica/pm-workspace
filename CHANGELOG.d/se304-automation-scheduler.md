---
version_bump: minor
section: Added
---

### Added

- SE-304 automation scheduler: unified scheduled task infrastructure. Task store (JSON), async scheduler loop (catch-up, skip-on-overlap), scoped approvals, CLI `savia-automations.sh` with 10 commands, 6 default tasks (morning-brief, pr-stale-check, drift-daily, memory-consolidation, weekly-report, dependency-cve-scan). 46 tests. Supersedes SE-279 and overnight-sprint.
