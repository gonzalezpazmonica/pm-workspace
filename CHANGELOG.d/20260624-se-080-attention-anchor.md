## SE-080 -- Attention-anchor vocabulary (Era 199)

### Added

- `docs/rules/domain/attention-anchor.md`: canonical doc defining 4 Genesis patterns (B8 ATTENTION ANCHOR, B9 GOAL STEWARD, A7 ADVERSARIAL REVIEW, A9 SUPERVISED EXECUTION) with their pm-workspace implementations. Already existed with full content; verified complete.
- `scripts/attention-anchor-check.sh`: verifier script. Searches workspace for references to each of the 4 patterns. Output JSON: checked, found, missing, details. Always exits 0.
- `tests/bats/test-se-080-attention-anchor.bats`: 6 BATS tests covering doc existence, pattern mentions, cross-references in radical-honesty.md and autonomous-safety.md, check script JSON validity, and Genesis citation.

### Cross-references (all already in place)

- `docs/rules/domain/radical-honesty.md`: "implementa Genesis B9 GOAL STEWARD"
- `docs/rules/domain/autonomous-safety.md`: "implementa Genesis A9 SUPERVISED EXECUTION"
- `docs/rules/domain/code-review-court.md`: "implementa Genesis A7 ADVERSARIAL REVIEW"
- `docs/propuestas/SE-079-pr-plan-scope-trace-gate.md`: "Pattern alignment: Genesis B9 GOAL STEWARD + B8 ATTENTION ANCHOR"
