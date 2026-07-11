# Managed Artifacts Inventory — SE-260 S3

> Last updated: 2026-07-11
> Status per artifact: adapted | justified-out | pending

| # | Artifact | Target | Installer | Status |
|---|---|---|---|---|
| 1 | Git hooks (pre-commit, pre-push, commit-msg) | `.git/hooks/` | `scripts/install-git-hooks.sh` | adapted |
| 2 | Symlinks .opencode → .claude | `.opencode/{commands,hooks,skills,docs}` | `init-pm.sh` | justified-out |
| 3 | ACM maps | `.agent-maps/` | (none) | justified-out |

## Notes

- Artifact 2 (symlinks): managed by git (tracked in repo). No install/uninstall needed.
  Justified-out: contract does not apply to version-controlled files.
- Artifact 3 (ACM maps): conceptual; `.agent-maps/` directory not yet populated.
  Justified-out: no artifact to install until ACM mapping is materialized.
- Artifact 1 (git hooks): the only active managed artifact.
  Adapted: `install-git-hooks.sh` now wraps `scripts/lib/managed_artifacts.py`.
