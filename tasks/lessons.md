# Lessons Learned

Persistent log of corrections and patterns discovered during sessions.
Reviewed at session start to prevent recurrence. Newest entries first.

Format: `| date | category | lesson | source |`

---

| Date | Category | Lesson | Source |
|---|---|---|---|
| 2026-03-04 | CHANGELOG | Always add version link reference `[X.Y.Z]: URL` at bottom of CHANGELOG.md when creating a new `## [X.Y.Z]` header. Validated by `scripts/validate-changelog-links.sh` and `prompt-hook-commit.sh`. | User correction — v1.9.0 |
| 2026-03-03 | PII | Never include real company names, personal names, or handles in CHANGELOG, releases, commits, or PR descriptions. Use generic placeholders (test-org, alice, test company). | User correction — Era 21 |
| 2026-03-03 | Git | `git fetch origin --all` is invalid. Use `git fetch --all` or `git fetch origin` (without --all). | Test failure — Era 22 |
| 2026-03-03 | Testing | `assert_ok` checking `$?` after `TOTAL=$((TOTAL+1))` always returns 0. Pass the command as arguments to the assert function instead. | Test failure — Era 22 |
| 2026-03-03 | Git | savia-branch.sh dispatcher uses short names (read, write, exists) not function names (do_read, do_write, do_exists). | Test failure — Era 22 |
| 2026-03-03 | Bash | `!` negation doesn't work inside `"$@"` expansion. Use a separate `assert_fail` helper instead. | Test failure — Era 22 |
| 2026-03-03 | Git | Default branch is `master` unless `init.defaultBranch` is configured. Always set `git config --global init.defaultBranch main` in test setup. | Test failure — Era 22 |
