# SE-290: Fix MCP Server Path Resolution

> **Status:** APPROVED · **Author:** Savia · **Date:** 2026-08-01
> **Type:** Bug Fix · **Priority:** HIGH
> **Depends on:** SE-286 (vaults-producto)

## Problem

MCP server configured with `--path vaults/SaviaLabs` in `.claude/mcp.json` is
serving the workspace root (`/home/monica/savia`, 18,676 notes) instead of
SaviaLabs (23 notes). This causes:
- 3x search latency (~1.4s vs ~0.25s)
- Timeout on `vault_health` and `vault_stats` (workspace root is too large)
- 18,676 notes indexed instead of 23 — 812x overhead

## Root Cause (3-layer failure)

### RC1: `--schema` option not registered → Commander crash
`src/cli/index.ts:36-41` — `serve` command defines only 4 options (transport,
port, host, path). `.claude/mcp.json` passes `--schema projects/savia-vaults/schema/entities`.
Commander 13.1.0 throws `error: unknown option '--schema'` → process exits
with code 1. MCP server never starts from this config.

### RC2: Fallback to `package.json` `mcp` config with no `--path`
`package.json:61-65` — the standard `mcp.server` section has `args: ["serve", "--transport", "mcp"]`
with **no `--path`**. When RC1 kills the `.claude/mcp.json` process, the
OpenCode/Claude Code host discovers the `package.json` fallback and uses it.
Commander's default for `--path` is `process.cwd()` = `/home/monica/savia`.

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

### Fix 2: Add `--path` to `package.json` mcp.server.args
**File:** `package.json`

```json
"mcp": {
    "server": {
      "command": "savia-vaults",
      "args": ["serve", "--transport", "mcp", "--path", "vaults/SaviaLabs"]
    }
  }
```

This ensures even if the `.claude/mcp.json` config is not used, the fallback
serves the correct vault.

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

1. MCP server starts with correct path: `node dist/cli/index.js serve --transport mcp --path vaults/SaviaLabs --schema projects/savia-vaults/schema/entities` → exit 0 (no "unknown option" error)
2. `stats --path vaults/SaviaLabs` → 23 notes (not 18676)
3. `search "roadmap" --path vaults/SaviaLabs` → <0.3s (not >1s)
4. `health-report --path vaults/SaviaLabs` → <0.3s (not timeout)
5. Re-run benchmark comparing CLI vs MCP with SaviaLabs vault
6. All existing tests still pass: `npm test`

## Acceptance Criteria

- [ ] `serve --schema` accepted without Commander error
- [ ] MCP starts with `--path vaults/SaviaLabs` and indexes 23 notes
- [ ] `package.json` `mcp.server.args` includes `--path vaults/SaviaLabs`
- [ ] `vault_health`, `vault_stats`, `vault_search` all complete in <1s via MCP
- [ ] `npm test` — 89 tests PASS
- [ ] `npm run typecheck` — no errors
- [ ] `npm run build` — no errors
