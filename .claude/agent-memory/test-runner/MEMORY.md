# Test Runner — Persistent Memory

> Test infrastructure patterns, coverage trends, and flaky test root causes.

## Discovered Patterns

| Date | Pattern | Context | Source |
|---|---|---|---|
| 2026-03-03 | Maintain test coverage ≥80% — lower thresholds create unmaintainable debt | Quality gate, coverage-scripts.md | TEST_COVERAGE_MIN_PERCENT config |
| 2026-03-02 | Always add [Trait("Category", "Unit")] to xUnit tests — enables filtering and fast runs | C# xUnit tests | Test-runner.md coverage-scripts section |
| 2026-03-01 | Use FluentAssertions for readable assertions — improves failure diagnostics | C# test readability | Code-reviewer feedback on test quality |

