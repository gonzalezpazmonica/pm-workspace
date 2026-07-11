# Managed Artifacts Contract — SE-260 S3

> Every artifact installed outside the repo tree must implement this contract.
> Artifacts: git hooks, symlinks, ACM maps, systemd units (if any).

## Operations

### init(root)
Validate canonical root: must be a git repo with expected structure.
- Returns: 0 if valid, 1 if not.
- Idempotent.

### install()
Install the artifact to its target location.
- If target exists WITHOUT this artifact's marker → **abort** (do not overwrite foreign files).
- If target exists WITH this artifact's marker → backup + replace.
- If target does not exist → create.
- After writing, insert marker: `# managed-by: savia <artifact-id> v<version> <timestamp>`

### sync()
Ensure the installed artifact matches the template.
- Compare installed content vs template.
- If different → reinstall (backup + replace).
- Two consecutive sync() calls → zero diff.
- Returns: 0 if in sync, 1 if reinstall was needed.

### uninstall()
Remove the artifact and restore previous state.
- If backup exists → restore byte-for-byte.
- If no backup and artifact has our marker → remove.
- If no backup and no marker → **abort** (do not touch foreign files).
- Returns: 0 if restored/removed, 1 if blocked.

### probe()
Health check: is the artifact healthy?
- Verify artifact exists at target.
- Verify marker matches expected artifact-id.
- Verify content matches template (or at least structure is valid).
- Returns: 0 = healthy, 1 = degraded, 2 = missing.

### backup()
Create a pre-mutation backup.
- Copy target to `output/artifacts-backup/<artifact-id>/<timestamp>/`.
- Returns: 0 on success.

## Marker Format

```
# managed-by: savia <artifact-id> v<version> <iso-timestamp>
```

## Permissions

- No file outside the declared target path may be modified.
- Backup directory permissions: 0700.
- Artifact target permissions: preserve existing or default 0755 (scripts) / 0644 (config).

## Library

Reference implementation: `scripts/lib/managed_artifacts.py`
