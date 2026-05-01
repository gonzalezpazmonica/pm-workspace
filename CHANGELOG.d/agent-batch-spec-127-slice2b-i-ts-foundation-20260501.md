---
version_bump: minor
section: Added
---

### Added

#### SPEC-127 Slice 2b-i IMPLEMENTED — TypeScript plugin foundation for OpenCode v1.14

- `.opencode/package.json` — declara `@opencode-ai/plugin` dependency. ESM type=module. Private (no publishable). OpenCode runtime ejecuta `bun install` automáticamente al arrancar — no requiere paso manual del usuario.
- `.opencode/tsconfig.json` — TS strict mode, ES2022 target, Bundler module resolution (compatible con Bun runtime). `noEmit: true` (typecheck-only, OpenCode loader interpreta TS directamente). Includes `plugins/**/*.ts`, excludes `node_modules`.
- `.opencode/plugins/savia-foundation.ts` — plugin foundation no-op. Importa `Plugin` type desde `@opencode-ai/plugin`. Exporta `SaviaFoundationPlugin` como named + default export. Async function. Returns `{}` (empty hooks). Documenta el porting roadmap de Slice 2b-ii: 5 hooks TIER-1 a portar (validate-bash-global, block-credential-leak, block-gitignored-references, prompt-injection-guard, tdd-gate).
- `.opencode/plugins/savia-foundation.test.ts` — contract test scaffold con bun:test runner. 3 tests: plugin es async function, returns empty hooks {}, robust to partial context. **Bun runtime no se ejecuta en CI todavía** — Slice 2b-ii añade el test runner. Por ahora el contract es enforced por BATS estructural.
- `.opencode/plugins/README.md` — porting roadmap doc (60 líneas). Explica por qué existe el folder (OpenCode v1.14 no ejecuta `.sh` hooks nativamente), toolchain requirements, los 5 hooks TIER-1 a portar en 2b-ii (uno por PR), y safety boundaries (PV-01: hooks `.sh` originales intocados).

#### Tests de regresión

- `tests/structure/test-spec-127-slice2b-i-ts-toolchain.bats` — 40 tests certified. Estructura:
  - **package.json ×6**: existe + valid JSON + declara @opencode-ai/plugin + type=module + private=true + references SPEC-127
  - **tsconfig.json ×6**: existe + valid JSON + strict + noEmit + includes plugins + excludes node_modules
  - **Foundation plugin ×7**: TS file exists + imports Plugin type + exports named + default + async function + returns empty {} + documents top 5 hooks roadmap + references SPEC-127 + provider-agnostic-env
  - **Test scaffold ×5**: .test.ts exists + imports SaviaFoundationPlugin + bun:test runner + verifies empty hooks + 3+ test cases
  - **Plugins README ×5**: existe + documents 5 hooks porting + references Slice 2b + explains why folder exists + ≤150 lines cap
  - **PV-06 ×2**: foundation plugin sin vendors hardcoded + package.json sin vendor-specific clients
  - **Spec ref ×3**: SPEC-127 declares Slice 2 + ref in test + foundation documents 2b-i + 2b-ii
  - **Edge ×3**: foundation file non-empty (>200 bytes) + ≤200 lines + package.json description mentions Slice 2b-i / foundation
  - **Coverage ×3**: foundation destructures expected context fields (project/$/directory) + plugins README mentions classifier report + directory structure complete

### Why this matters

OpenCode v1.14 **no ejecuta los 64 hooks `.sh`** de Savia nativamente. El classifier de Slice 2a identificó 23 hooks TIER-1 portables a TS plugin (incluidos los 3 safety-critical: block-credential-leak, block-gitignored-references, prompt-injection-guard). Slice 2b-i establece la fundación TypeScript — package.json, tsconfig, plugin stub, test scaffold, README — para que Slice 2b-ii (el port real de los 5 hooks top) pueda concentrarse en la lógica sin re-establecer infrastructura. El stub es **no-op**: cero modificación del comportamiento existente bajo Claude Code (PV-01). Cuando un usuario arranque OpenCode, `bun install` carga el plugin, OpenCode lo registra, y como returns `{}` no toca nada — todo ready para Slice 2b-ii.

### Hard safety boundaries

- **PV-01 Backward compat absoluto**: cero modificación de los 64 hooks `.sh` existentes. Solo se añade infrastructura nueva en `.opencode/plugins/`.
- **PV-06 No vendor lock-in**: BATS tests verifican que ni el plugin TS ni el package.json mencionan vendors comerciales hardcoded.
- TDD enforced: el `.test.ts` se creó **antes** del plugin (TDD gate hook lo bloqueó hasta que existiera).
- 150-line cap respetado en plugins/README.md.
- Cero red en runtime (el bun install que OpenCode dispara descarga npm packages — esto es runtime de OpenCode, no del repo).
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-127-slice2b-i-ts-toolchain-20260501`, sin merge autónomo.

### Spec ref

SPEC-127 (`docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md`) → Slice 2b-i IMPLEMENTED 2026-05-01. Foundation lista para Slice 2b-ii (port de top 5 hooks TIER-1). Slice 2b-ii puede ir en 1 PR único (~10-12h) o 5 PRs incrementales (uno por hook, ~2h cada uno) según preferencia del operador.
