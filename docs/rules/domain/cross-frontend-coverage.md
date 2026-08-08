# Cross-Frontend Coverage — Modelo operacional Claude Code ↔ OpenCode ↔ Copilot CLI

> **Status:** SE-178 verified 2026-06-07. Fuente única operacional.
> Reemplaza la dispersión de información entre `hook-parity.md` (SE-173), `HOOKS-STRATEGY.md` (SE-100, obsoleto sobre Copilot Enterprise — SE-179 lo actualiza), y `provider-agnostic-env.md`.

## TL;DR (para revisor a las 3am)

pm-workspace soporta **3 frontends de IA** con **cobertura runtime 67/67** en los 3 + **2 capas defensivas commit/push** universales:

| Target frontend | Cobertura runtime | Capas commit/push |
|---|:-:|:-:|
| Claude Code nativo | **67/67** hooks (C1 directo) | ✅ activas |
| OpenCode v1.14+ con plugin | **67/67** hooks (C2 bridge) + 14 reforzados (C3 TS native) | ✅ activas |
| Copilot CLI Enterprise (>=1.0.60) | **67/67** hooks (vía `.github/hooks/savia.json` generado desde `.claude/settings.json`) | ✅ activas |

**No hay degradación en ninguno de los 3 targets.** Validado empíricamente 2026-06-08.

**Ajuste post-SE-179** (SE-180, 2026-06-08): Las docs de docs.github.com sugieren que Copilot CLI lee `.claude/settings.json` cross-tool, pero verificación empírica + inspección del binario `app.js` de Copilot CLI 1.0.60 muestra que **solo lee `.github/hooks/*.json` desde gitRoot**. Por eso este workspace genera `.github/hooks/savia.json` como artefacto derivado de `.claude/settings.json` (fuente única) vía `bash scripts/generate-github-hooks.sh`. Sin esa generación, los hooks NO se disparan en Copilot CLI.

**Opt-in del usuario**: Copilot CLI pide permiso explícito la primera vez que detecta hooks en un workspace. Si el usuario rechaza el prompt, los hooks no se disparan (documentado en runbook).

## Modelo de 4 capas (C0 fuente + C1-C3 dispatchers)

```
                ┌──────────────────────────────────────────┐
                │ C0 — Fuente única: .claude/settings.json │
                │      67 hook bindings registrados        │
                └────────────────┬─────────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────┐
│ Claude Code     │    │ OpenCode v1.14+ │    │ Copilot CLI         │
│ nativo (C1)     │    │ (C2 + C3)       │    │ Enterprise          │
│                 │    │                 │    │ (C0 cross-tool)     │
│ Ejecuta los     │    │ C2 bridge:      │    │                     │
│ 67 .sh directo  │    │ savia-gates     │    │ Lee mismo settings  │
│ via settings    │    │ via Bun shell.  │    │ y ejecuta bash      │
│                 │    │                 │    │ scripts nativos.    │
│                 │    │ C3 defense-in-  │    │                     │
│                 │    │ depth: 14 TS    │    │ Eventos: pre/post   │
│                 │    │ guards puros.   │    │ ToolUse, session,   │
│                 │    │                 │    │ stop, preCompact... │
│                 │    │                 │    │                     │
│ 67/67           │    │ 67/67 + 14 dup  │    │ 67/67               │
└─────────────────┘    └─────────────────┘    └─────────────────────┘
            │                    │                      │
            └────────┬───────────┴──────────┬───────────┘
                     │                      │
              Capa 2: Git hooks      Capa 3: CI gates
              (pre-commit/push,      (validate-ci-local +
              ~10 controles)         GH Actions, 50+ controles)
```

## C0 — Fuente única (`.claude/settings.json`)

67 hook bindings sobre 8 eventos (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`, `Stop`, `PreCompact`, `SubagentStop`).

Los 3 frontends leen este fichero, cada uno con su mecanismo:

- **Claude Code**: lectura nativa, ejecución directa.
- **OpenCode v1.14+**: plugin TS `savia-gates` lee y ejecuta vía Bun shell.
- **Copilot CLI Enterprise**: cross-tool support oficial — el CLI lee `.claude/settings.json` y `.claude/settings.local.json` como una de sus fuentes (`~/.copilot/settings.json`, `.github/copilot/settings.json`, `.claude/settings.json`, ...).

### Invariantes implícitos enforced

| ID | Invariante | Test |
|---|---|---|
| INV-1 | `.opencode/.claude → .claude/` symlink válido | `test-cross-frontend-invariants.bats` |
| INV-2 | `.opencode/hooks → .claude/hooks` symlink válido | `test-cross-frontend-invariants.bats` |
| INV-3 | cada `.ts` guard tiene `.sh` sibling | `test-cross-frontend-invariants.bats` |
| INV-4 | schema `.claude/settings.json` `hooks` block compatible con [Copilot CLI hooks reference (docs.github.com/en/copilot)](https://docs.github.com/en/copilot/reference/hooks-configuration) | SE-179 (validación empírica + snapshot test) |

## C1 — Claude Code nativo

Claude Code lee `.claude/settings.json` y dispara los 67 hooks bash directamente.

**Cobertura: 67/67**. Implementación: Anthropic Claude Code CLI (canonical).

## C2 — OpenCode v1.14+ plugin bridge

Plugin TS `scripts/opencode-plugin/savia-gates/` (SE-077 Slice 2). Lee el **mismo** `.claude/settings.json`, construye `event→hooks[]` map, y ejecuta los `.sh` via Bun shell.

**Tabla de mapeo de eventos** (`lib/manifest.ts`):

| Event Claude Code | Event OpenCode SDK |
|---|---|
| PreToolUse | `tool.execute.before` |
| PostToolUse | `tool.execute.after` |
| UserPromptSubmit | `chat.message` |
| SessionStart | `event:session.created` |
| SessionEnd | `event:session.deleted` |
| Stop | `event:session.stopped` |
| SubagentStart | `event:subagent.started` |
| SubagentStop | `event:subagent.completed` |
| TaskCreated | `event:task.created` |
| TaskCompleted | `event:task.completed` |
| PreCompact | `experimental.session.compacting` |

**Cobertura: 67/67**. Requiere Bun shell.

## C3 — OpenCode TS native (defense-in-depth)

Plugin `.opencode/plugins/savia-foundation.ts` (SPEC-127 + SPEC-OC-01) registra 14 guards re-implementados en TypeScript puro, sin shell. Estos guards corren **además** del bridge en OpenCode v1.14+ (defense-in-depth).

**Justificación previa:** se asumía que Copilot Enterprise no tenía shell. Esta asunción quedó obsoleta en 2026 (ver hallazgo abajo). C3 sigue siendo útil como defense-in-depth pero **NO es ya una "única defensa runtime" en ningún target**.

## Hallazgo crítico 2026-06-07 — cross-tool support en Copilot CLI

GitHub Copilot CLI Enterprise lee `.claude/settings.json` **nativamente** como una de sus fuentes oficiales de configuración de hooks. Soporta los 8 eventos que usamos y ejecuta bash scripts directamente.

**Evidencia documental:**

- [GitHub Copilot hooks reference - docs.github.com/en/copilot/reference/hooks-configuration](https://docs.github.com/en/copilot/reference/hooks-configuration) lista `.claude/settings.json` y `.claude/settings.local.json` entre las fuentes de hook config.
- 13 eventos soportados en Copilot CLI: `sessionStart`, `sessionEnd`, `userPromptSubmitted`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `preCompact`, `agentStop`, `subagentStart`, `subagentStop`, `errorOccurred`, `notification`, `permissionRequest`. Cubre los 8 que usamos.
- Tipos de hook handler: `command` (bash/PowerShell), `http` (POST), `prompt` (sessionStart only).
- Bash scripts soportados con `chmod +x` + shebang. Mismo formato que Claude Code.

**Implicación:** la afirmación previa de "Copilot Enterprise sin hooks → degradación" en `.opencode/HOOKS-STRATEGY.md` (SE-100, mayo 2026) está **obsoleta**. SE-179 actualiza ese doc.

**Validación pendiente (SE-179):**

- Versión mínima de Copilot CLI con cross-tool support estable.
- Si todos los 8 eventos están en GA o algunos en preview.
- Smoke test empírico con Copilot CLI instalado.

## Capas defensivas commit/push (2 y 3)

Estas capas son **frontend-agnostic** — corren igual en todos los targets.

### Capa 2: Git hooks (commit time)

`scripts/install-git-hooks.sh` instala ~10 controles que corren en `pre-commit`, `pre-push`, `commit-msg`:

- Secret scan (credentials staged)
- Force push protection a main
- Commit message convention
- Savia Shield scan
- Firma `.pr-plan-ok` (SDD gate)

### Capa 3: CI (push time + PR time)

`scripts/validate-ci-local.sh` y GitHub Actions / Azure Pipelines ejecutan ≥50 gates:

- Lint cross-language
- Test suites con cobertura
- Drift checks
- Confidentiality scan
- BATS suites incluyendo `test-cross-frontend-invariants.bats`

## Auditoría y enforcement automático

### Tests existentes

| Test | Mide | Pase verificado |
|---|---|---|
| `bats tests/parity/test-hook-parity.bats` | Paridad funcional .sh↔.ts (2 high-level cases) | 2/2 — 2026-06-07 |
| `bats tests/structure/test-opencode-parity-audit.bats` | Audit script estructura + DUAL_HOOKS coherence | 22/22 — 2026-06-07 |
| `bash tests/parity/hook-parity-harness.sh` | Veredicto BLOCK/ALLOW idéntico .sh vs .ts | 20/20 — 2026-06-07 |
| `bash scripts/hooks-integrity-check.sh` | 0 phantoms (registrados sin fichero) + lista orphans | exit 2, 0 phantom, 6 orphan (SPEC-071 deuda) — 2026-06-07 |
| `bats tests/structure/test-cross-frontend-invariants.bats` | INV-1 (.opencode/.claude symlink) + INV-2 (.opencode/hooks symlink) + INV-3 (sibling TS↔.sh) | 4/4 — 2026-06-07 |

### Test pendiente SE-179

`tests/structure/test-copilot-cli-compat.bats` — INV-4: schema `.claude/settings.json` `hooks` block compatible con Copilot CLI reference.

### Audit `scripts/opencode-parity-audit.sh` (clarificación SE-178)

El audit **NO** mide cobertura cross-frontend. Mide:

- **Si plugin C2 está cargado** (manifest presente): bindings de settings.json que tienen entry en manifest dinámico.
- **Si plugin C2 no está cargado** (manifest ausente): exit code 3 — no es un gap, es "plugin no desplegado en esta máquina".

Su output incluye marcador `[AUDIT-SEMANTIC-NOTE]` al pie aclarando esto.

## Riesgos conocidos del modelo

1. **Symlink roto** (`.opencode/.claude` o `.opencode/hooks`) → C2 cae silenciosamente a 0/67. Mitigación: INV-1/INV-2 tests.
2. **Drift TS↔SH** (cambio en .sh sin cambio en .ts equivalente) → paridad funcional se rompe. Mitigación: `hook-parity-harness.sh` veredicto comparison.
3. **Plugin no desplegado en máquina de dev**: audit reporta gap=67 (manifest ausente). NO es bug, es estado. Documentado en sección clarificación del audit.
4. **Schema drift Copilot CLI ↔ Claude Code** (INV-4): si GitHub cambia el schema esperado y Anthropic no (o viceversa), Copilot CLI Enterprise pierde compatibilidad silenciosa. Mitigación: SE-179 añade test snapshot del schema.
5. **Eventos de OpenCode SDK no mapeados** (futuro): si OpenCode añade nuevo evento, C2 lo ignora hasta que `manifest.ts` HANDLER table se actualice. Mitigación: documentación + revisión periódica.

## Histórico

- **2026-03-10**: wrappers manuales en `scripts/opencode-hooks/wrappers/` (reemplazados).
- **2026-04-09**: symlinks unifican fuente (`.opencode/{commands,hooks,skills} → .claude/*`).
- **2026-05-06**: GitHub anuncia Enterprise-managed plugins en Copilot CLI public preview ([blog](https://github.blog/changelog/2026-05-06-enterprise-managed-plugins-in-github-copilot-cli-are-now-in-public-preview/)).
- **2026-05-27 (SE-094)**: integrity check con búsqueda multidir.
- **2026-05-27 (SE-100)**: HOOKS-STRATEGY.md unificado (con asunción "Copilot Enterprise sin hooks" — obsoleta junio 2026).
- **2026-06-02**: GitHub anuncia [Copilot SDK GA](https://github.blog/changelog/2026-06-02-copilot-sdk-is-now-generally-available/).
- **2026-06-05 (SE-173)**: hook-parity.md formaliza disciplina .sh↔.ts.
- **2026-06-07 (SE-177)**: PR cerrado sin merge tras detectar premisa falsa sobre el audit.
- **2026-06-07 (SE-178)**: este documento consolida modelo operacional verificado. Hallazgo cross-tool Copilot CLI.
- **2026-06-07 (SE-179, pending)**: validación empírica + actualizar HOOKS-STRATEGY.md.

## Anexo histórico

Análisis bidireccional exhaustivo de 2026-06-07: `docs/parity-analysis/2026-06-07-cross-frontend.md`.

## Referencias normativas

- SE-077 — bridge plugin spec
- SE-094 — hooks integrity check
- SE-100 — HOOKS-STRATEGY consolidación (asunción Copilot Enterprise obsoleta)
- SE-127 — provider-agnostic foundation
- SE-173 — hook parity discipline
- SPEC-127 — savia-foundation TS plugin
- SPEC-OC-01 — Savia Shield OpenCode adaptation
- SPEC-071 — Hook System Overhaul (orphan hooks, fuera de scope)

## Referencias externas

- [GitHub Copilot hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration)
- [Using hooks with GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks)
- [OpenCode Plugins documentation](https://opencode.ai/docs/plugins/)
- [Enterprise-managed plugins in Copilot CLI (May 2026)](https://github.blog/changelog/2026-05-06-enterprise-managed-plugins-in-github-copilot-cli-are-now-in-public-preview/)
- [Copilot SDK GA (June 2026)](https://github.blog/changelog/2026-06-02-copilot-sdk-is-now-generally-available/)
