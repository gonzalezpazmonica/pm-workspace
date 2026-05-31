---
version_bump: patch
section: Added
---

### Added

- SPEC-161 PROTECTED_JOB_NAMES: hook + YAML allowlist blocking costly agents (architect, sdd-spec-writer, pentester, ...) in autonomous loops (overnight-sprint, code-improvement-loop). Override via SAVIA_PROTECTED_JOB_OVERRIDE env. Fail-safe permissive if YAML missing. 15 BATS tests.

