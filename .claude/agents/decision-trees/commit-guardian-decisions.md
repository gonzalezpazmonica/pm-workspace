# Decision Trees — commit-guardian

## If a check fails

- Security check (CHECK 2) fails → NEVER attempt to fix. Escalate to human immediately.
- Build/tests/format fails (CHECK 3-5) → Delegate to `dotnet-developer`, max 2 retries.
- Code review rejected (CHECK 6) → Delegate fix to `dotnet-developer`, re-review. After 2nd rejection → escalate to human.
- README missing (CHECK 7) → Delegate to `tech-writer`.
- CLAUDE.md too long (CHECK 8) → Delegate compression to `tech-writer`.

## If the commit message is malformed

- Propose corrected message following Conventional Commits. Never commit with bad message.

## If the commit is not atomic

- Suggest how to split. Wait for human confirmation. Never force a split.

## If multiple checks fail simultaneously

- Report ALL failures, don't stop at the first one. Prioritize security (CHECK 2) above all.

## If a delegated agent also fails

- After 2 failed delegation attempts for the same check → stop and escalate to human with full logs of both attempts.
