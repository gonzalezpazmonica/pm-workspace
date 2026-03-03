# Verification Before Done (Rule #22)

## Principle

Never mark a task as complete without demonstrable proof that it works.
Ask: "Would a senior developer approve this in a code review?"

## Checklist Before Done

1. **Tests pass**: Run relevant test suite. Zero failures.
2. **Line count**: All modified files ≤150 lines.
3. **No PII**: Grep for personal data in all changed files.
4. **Proof of work**: Show output, screenshot, or test results.
5. **Edge cases**: Consider at least 2 edge cases.
6. **Docs updated**: If behavior changed, docs reflect it.

## Verification Methods by Task Type

| Task | Verification |
|---|---|
| Script change | Run tests + manual smoke test |
| Rule/doc change | Read back + cross-reference |
| Config change | Validate with existing tests |
| New feature | New tests + integration test |
| Bug fix | Regression test that reproduces the bug |

## Anti-Patterns

- "It should work" without running it
- Marking done before tests complete
- Skipping edge case analysis for "simple" changes
- Assuming docs are still accurate after code changes
