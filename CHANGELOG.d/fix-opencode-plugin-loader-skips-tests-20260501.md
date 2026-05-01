---
version_bump: patch
section: Fixed
---
- **`.opencode/plugins/`**: reorganized so OpenCode v1.14 plugin loader only sees `Plugin`-shaped files at top level. Guards moved to `guards/`, tests to `__tests__/`. Top level now contains only `savia-foundation.ts`. Without this, any OpenCode CLI command (including `opencode auth login`) crashed with `undefined is not an object (evaluating 'J.auth')` because the loader wraps every top-level `.ts` as a plugin and the guard/test modules don't export the plugin shape.
- **`scripts/opencode-migration-smoke.sh`**: updated foundation file paths to point at `guards/` subfolder.
- **`.opencode/plugins/README.md`**: documented the layout invariant ("only plugin-shaped files at top level") so future ports don't reintroduce the regression.
