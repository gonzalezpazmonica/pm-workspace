## se266-shell-safety

- Extends agent-git-discipline hook with shell safety layer (v2)
- After session incident 2026-07-13: agent executed destructive commands outside workspace
- Added blocking of recursive delete, disk writes, mass ownership changes
- 27/27 manual tests pass (30 BATS in test-se-266-agent-git.bats)
- Spec updated with v2 scope and incident lesson learned
