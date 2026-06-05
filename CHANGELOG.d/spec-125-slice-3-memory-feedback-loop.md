---
version_bump: minor
section: Added
---

### Added

- SPEC-125 Slice 3: Memory feedback loop + tribunal calibration. Recorder followup-record.sh classifies user reactions (fp/fn/neutral). Calibrator calibrate.sh emits feedback memories from fp/fn records. Hook recommendation-tribunal-followup.sh wire-ready (no-op default). Canonical rule docs/rules/domain/tribunal-calibration.md. Classifier expanded with 4 new pattern groups (5/6 regression patterns caught by heuristic). 42 BATS tests, score 86/100 certified.

