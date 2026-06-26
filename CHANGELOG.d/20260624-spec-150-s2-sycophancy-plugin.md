## SPEC-150 Slice 2 — sycophancy-guard.ts plugin (2026-06-24)

### Added
- `.opencode/plugins/guards/sycophancy-guard.ts`: TypeScript port of `sycophancy-strip.sh`. Exports `detectSycophancy` (pure function, testable) and `sycophancyGuard` (after-guard). Modes: shadow (default), warn, block. Master switch: `SAVIA_ANTIADULATION=off`.
- `.opencode/plugins/__tests__/sycophancy-guard.test.ts`: 14 unit tests covering detection, shadow/warn/block modes, master-off bypass, clean-output no-op, positional bounds.
- `tests/bats/test-spec-150-s2-plugin.bats`: 6 bats tests covering file existence, pattern presence, bash hook integrity, migration doc decision, foundation wiring, exports.

### Changed
- `.opencode/plugins/savia-foundation.ts`: registers `sycophancyGuard` in `AFTER_GUARDS` chain (SPEC-150 Slice 2).
- `docs/rules/domain/hook-multihandler-migration.md`: updated to `status: implemented`, `slice_final: 2`. Documents 2026-06-24 decision: FP rate = 0.00, ROI below threshold for Slices 3-6. Slices 3-6 descoped with reopen criterion (FP >= 2%).
- `docs/propuestas/SPEC-150-hooks-multi-handler-migration.md`: status flipped `IN_PROGRESS → IMPLEMENTED` with reduced-scope note.

### Decision
Slice 1 probe measured FP rate = 0.00 (0%) across 6 hooks. Migration criterion (FP >= 5%) not met for full migration. Only Slice 2 (sycophancy, highest semantic value) executed. Bash hook `sycophancy-strip.sh` retained as Layer 1 fallback per SPEC-192 layered architecture.
