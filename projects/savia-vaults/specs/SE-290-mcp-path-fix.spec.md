# SE-290: Fix MCP Server Path Resolution

> **Status:** APPROVED · **Author:** Savia · **Date:** 2026-08-01
> **Type:** Bug Fix · **Priority:** HIGH
> **Depends on:** SE-286 (vaults-producto)

## Problem

MCP server configured with a specific vault path via `--path <vault>` in
`.claude/mcp.json` (or other MCP config) serves the workspace root instead
of the intended vault. The workspace root can be much larger than the target
vault, causing:
- Significantly higher search latency
- Timeout on `vault_health` and `vault_stats`
- Unnecessary index overhead scanning unrelated files

## Root Cause (3-layer failure)

### RC1: `--schema` option not registered → Commander crash
`src/cli/index.ts:36-41` — `serve` command defines only 4 options (transport,
port, host, path). If any MCP config passes `--schema <dir>`, Commander 13.1.0
throws `error: unknown option '--schema'` → process exits with code 1.
MCP server never starts from this config.

### RC2: Fallback to `package.json` `mcp` config with default path
`package.json:61-65` — the standard `mcp.server` section has `args: ["serve", "--transport", "mcp"]`
with **no `--path`**. When RC1 kills the external MCP config process, the
host discovers `package.json` fallback. Commander's default for `--path` is
`process.cwd()` which equals the workspace root.

### RC3: `schemaDir` never wired through in CLI
`src/types.ts:10` — `schemaDir` exists in `VaultConfig` interface.
`src/cli/index.ts:18-20` — `makeConfig()` never sets `schemaDir`.
The feature was designed (consumed by SchemaRegistry, Introspector, QueryEngine)
but never integrated into the CLI layer.

## Fix

### Fix 1: Add `--schema` to serve command + wire schemaDir
**File:** `src/cli/index.ts`

```typescript
program.command('serve').description('Start MCP or A2A server')
  .option('--transport <type>', 'mcp or a2a', 'mcp')
  .option('--port <port>', 'Port for A2A', '8923')
  .option('--host <host>', 'Bind host', '127.0.0.1')
  .option('-p, --path <path>', 'Vault path', process.cwd())
  .option('--schema <dir>', 'Entity schema directory')       // NEW
  .action(async (opts) => {
    const config = makeConfig('vault', opts.path);
    if (opts.schema) config.schemaDir = opts.schema;          // NEW
    // ... rest unchanged
```

### Fix 2: Fix `package.json` mcp.server fallback
**File:** `package.json`

The `package.json` `mcp.server` section keeps `["serve", "--transport", "mcp"]`
without a hardcoded `--path` (vault paths are deployment-specific and belong
in the host's MCP config, not in the public package). The fix makes `--schema`
available so external MCP configs that pass it no longer crash.


### Fix 3: Fix `package.json` `main` field
**File:** `package.json`

Change `"main": "dist/server/index.js"` → `"main": "dist/cli/index.js"`.
File `dist/server/index.js` does not exist (server classes are at
`dist/server/mcp.js` and `dist/server/a2a.js`).

### Fix 4: Fix `--path` description in `introspect` command
**File:** `src/cli/index.ts:75`

```typescript
.option('-p, --path <path>', process.cwd())  // BEFORE: no description
.option('-p, --path <path>', 'Vault path', process.cwd())  // AFTER
```

## Rebuild

```bash
cd projects/savia-vaults && npm run build
```

## Verification

1. MCP server starts: `serve --transport mcp --path <any-vault> --schema <dir>` → exit 0 (no "unknown option" error)
2. `stats --path <any-vault>` works correctly with the specified vault
3. `search "query" --path <any-vault>` completes in <0.3s on small vaults
4. `health-report --path <any-vault>` completes without timeout
5. All existing tests still pass: `npm test`

## Acceptance Criteria

- [ ] `serve --schema` accepted without Commander error
- [ ] MCP starts with `--path <any-vault>` and indexes only that vault
- [ ] `vault_health`, `vault_stats`, `vault_search` all complete for any vault path
- [ ] `npm test` — 125 tests PASS
- [ ] `npm run typecheck` — no errors
- [ ] `npm run build` — no errors
