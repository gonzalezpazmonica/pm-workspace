---
version_bump: minor
section: Changed
---

### Changed

- SE-305 dynamic BATS test selection: CI now runs only tests affected by changed files instead of the full 666-test suite. Dependency map generator (`ci-bats-deps.sh`), test selector (`ci-select-bats.sh`), manual dir rules. 15 core tests always run, 30% threshold falls back to full suite. PR BATS time reduced from ~5min to <60s.
