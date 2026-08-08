---
task_id: SE-180
pbi_id: SE-180
proyecto: pm-workspace
sprint: 2026-23
status: APPROVED
approved_at: 2026-06-08
priority: critical                  # Corrige afirmación falsa de SE-179 validada empíricamente
developer_type: agent
max_turns: 6
modelo: claude-opus-4-8
creado_por: sdd-spec-writer (sesión interactiva)
fecha_creacion: 2026-06-08
security_review: required           # genera fichero leído por agente externo, validar shape
corrects: SE-179                    # SE-179 afirmó "Copilot CLI lee .claude/settings.json" — empíricamente falso en 1.0.60
related_specs: [SE-077, SE-178, SE-179]
---

# Spec: SE-180 — Generated `.github/hooks/savia.json` for Copilot CLI

**Status:** APPROVED · **Sprint:** 2026-23 · **Creado:** 2026-06-08

## Contexto

SE-179 documentó que Copilot CLI Enterprise lee `.claude/settings.json` natively vía cross-tool support (citando docs.github.com/en/copilot/reference/hooks-configuration). **Esa afirmación es falsa en la práctica para Copilot CLI 1.0.60**, verificado empíricamente el 2026-06-08:

1. Test inicial con prompt de credential leak en Copilot CLI sobre el workspace tal cual → el comando se ejecutó sin bloqueo, los hooks de `.claude/settings.json` NO se dispararon.

2. Investigación del binario (`/Users/.../@github/copilot/app.js`) reveló:
   ```js
   getHooksDir(e) {
     const root = gitRoot(e?.workingDirectory || process.cwd());
     return { hooksDir: path.join(root, ".github", "hooks"), baseDir: root };
   }
   ```
   Copilot CLI 1.0.60 busca hooks únicamente en `.github/hooks/` desde el gitRoot. No tiene parser para `.claude/settings.json`.

3. Tras generar `.github/hooks/savia.json` derivado de `.claude/settings.json` y opt-in del usuario, repetir el mismo prompt → bloqueo correcto con mención a `block-credential-leak`.

## Hallazgo adicional (UX importante)

Copilot CLI pide **opt-in del usuario** la primera vez que detecta hooks en un workspace. Si el usuario rechaza o no ha respondido, los hooks no se disparan. Documentado en el runbook.

## Objetivo

Garantizar que los 67 hook bindings de `.claude/settings.json` también se ejecutan en Copilot CLI 1.0.60+, manteniendo `.claude/settings.json` como **fuente única de verdad** (SSoT).

## No-objetivos

- **NO** duplicar la lógica de hooks. `.github/hooks/savia.json` es derivado mecánicamente.
- **NO** editar `.github/hooks/savia.json` manualmente. Editar `.claude/settings.json` y regenerar.
- **NO** portar hooks a TypeScript. El plugin `savia-foundation.ts` con 14 guards TS sigue como defense-in-depth, no se extiende.
- **NO** modificar la lógica de los `.sh` hooks. Son los mismos en los 4 frontends.

## Diseño

```
                                                          [SSoT]
                                                ┌────────────────────────┐
                                                │ .claude/settings.json  │
                                                │   67 hook bindings     │
                                                └───────────┬────────────┘
                                                            │
                  ┌─────────────────┬───────────────────────┼───────────────────────┐
                  │                 │                       │                       │
                  ▼                 ▼                       ▼                       ▼
        Claude Code         OpenCode bridge         OpenCode TS native       Copilot CLI
        (lee directo)       (savia-gates: lee       (savia-foundation:       (NO lee directo)
                             settings.json y         14 guards TS para                │
                             shellea via Bun)        defense-in-depth)                │
                                                                                      ▼
                                                                          ┌───────────────────────┐
                                                                          │ generate-github-hooks │ ← script
                                                                          │ (deriva del SSoT)     │
                                                                          └───────────┬───────────┘
                                                                                      ▼
                                                                       .github/hooks/savia.json
                                                                       (artefacto generado,
                                                                        en repo para CI)
```

## Criterios de Aceptación

| AC | Descripción | Verificación |
|---|---|---|
| AC-1 | Existe `scripts/generate-github-hooks.sh` que produce `.github/hooks/savia.json` desde `.claude/settings.json` | `test -x scripts/generate-github-hooks.sh && bash scripts/generate-github-hooks.sh && test -f .github/hooks/savia.json` |
| AC-2 | El JSON generado es válido y contiene `version: 1` + `hooks` keys con eventos camelCase (preToolUse, postToolUse, ...) | `python3 -c "import json; d=json.load(open('.github/hooks/savia.json')); assert d['version']==1; assert 'preToolUse' in d['hooks']"` |
| AC-3 | Eventos PascalCase → camelCase mapeados correctamente (Stop→agentStop, UserPromptSubmit→userPromptSubmitted, etc.) | inspección de `_meta` + `hooks` keys |
| AC-4 | Paths usan `$CLAUDE_PROJECT_DIR` (Copilot CLI expone esta env var a los hooks, verificado en binario app.js 2026-06-08). NO usar paths relativos `./` porque Copilot ejecuta hooks desde `.github/hooks/` cwd, no gitRoot | `grep -q "CLAUDE_PROJECT_DIR" .github/hooks/savia.json && ! python3 -c "import json,sys; d=json.load(open('.github/hooks/savia.json')); sys.exit(any(h.get('bash','').startswith('./') for ev in d['hooks'].values() for h in ev))"` |
| AC-5 | Test bats `tests/structure/test-github-hooks-sync.bats` verifica que `.github/hooks/savia.json` está sincronizado con `.claude/settings.json` | regenera + diff debe ser vacío |
| AC-6 | Runbook `docs/runbooks/copilot-cli-cross-tool-smoke.md` actualizado con: (a) sello `# Validated: 2026-06-08`, (b) hallazgo `.github/hooks/` path real, (c) opt-in del usuario documentado | grep en el fichero |
| AC-7 | `docs/rules/domain/cross-frontend-coverage.md` actualizado: tabla 4-capas con Copilot CLI leyendo `.github/hooks/savia.json` (no `.claude/settings.json`) | grep |
| AC-8 | `.opencode/HOOKS-STRATEGY.md` actualizado con el mismo hallazgo | grep |
| AC-9 | Regresión cero: 5 test suites previos siguen verdes (test-hook-parity, test-opencode-parity-audit, hook-parity-harness, test-cross-frontend-invariants, test-copilot-cli-compat) | 5 comandos independientes |
| AC-10 | `.github/hooks/savia.json` commiteado al repo (NO gitignored) — necesario para que CI y otras máquinas lo tengan disponible | `git ls-files .github/hooks/savia.json` retorna el path |

## OpenCode Implementation Plan

**Classification:** `cross-frontend-artifact-generation`.

Esta spec añade un generador + artefacto derivado:

- `scripts/generate-github-hooks.sh` (nuevo) — ejecutable, idempotente.
- `.github/hooks/savia.json` (nuevo, committeable) — derivado de `.claude/settings.json`.
- Actualizaciones documentales en `cross-frontend-coverage.md`, `HOOKS-STRATEGY.md`, runbook.
- Test bats nuevo (sync check).

**Sin cambios** en .sh hooks, plugin TS, audit script, ni en `.claude/settings.json`.

## Riesgos

1. **Drift entre `.claude/settings.json` y `.github/hooks/savia.json`** si alguien edita uno sin regenerar. Mitigación: AC-5 test bats falla si están desincronizados; pre-commit hook recomendado en SE-181 (follow-up).
2. **Schema evolution Copilot CLI**: si futuras versiones cambian el schema esperado (camelCase event names, matcher format), el generador queda desfasado. Mitigación: snapshot test del schema en `tests/structure/test-copilot-cli-compat.bats` ya existente detecta cambios.
3. **Hook .sh assume `CLAUDE_PROJECT_DIR`**: muchos hooks resuelven `$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh` que es independiente del cwd. Otros usan `$CLAUDE_PROJECT_DIR` literal. En Copilot CLI, ese env var no está definido. Mitigación: el savia-env.sh tiene fallback chain (SAVIA_WORKSPACE_DIR → CLAUDE_PROJECT_DIR → git rev-parse → pwd). Empíricamente verificado 2026-06-08 que `block-credential-leak.sh` funciona en Copilot CLI.
4. **Opt-in del usuario**: si el dev rechaza el prompt de Copilot CLI al cargar hooks, no se disparan. Mitigación: runbook documenta esto explícitamente.

## Verification Protocol

```bash
# AC-1, AC-2, AC-3, AC-4
test -x scripts/generate-github-hooks.sh
bash scripts/generate-github-hooks.sh
test -f .github/hooks/savia.json
python3 -c "
import json
d = json.load(open('.github/hooks/savia.json'))
assert d['version'] == 1
expected = {'preToolUse','postToolUse','sessionStart','sessionEnd','agentStop','preCompact','subagentStop','userPromptSubmitted'}
got = set(d['hooks'].keys())
assert got.issubset(expected), f'Unexpected keys: {got - expected}'
print('OK', len(got), 'event categories,', sum(len(v) for v in d['hooks'].values()), 'total entries')
"
! grep -q "CLAUDE_PROJECT_DIR" .github/hooks/savia.json

# AC-5
bats tests/structure/test-github-hooks-sync.bats

# AC-6
grep -q "Validated: 2026-06-08" docs/runbooks/copilot-cli-cross-tool-smoke.md
grep -q ".github/hooks" docs/runbooks/copilot-cli-cross-tool-smoke.md
grep -qi "opt-in" docs/runbooks/copilot-cli-cross-tool-smoke.md

# AC-7
grep -q ".github/hooks/savia.json" docs/rules/domain/cross-frontend-coverage.md

# AC-8
grep -q ".github/hooks" .opencode/HOOKS-STRATEGY.md

# AC-9 (regresión cero)
bats tests/parity/test-hook-parity.bats              # ≥2
bats tests/structure/test-opencode-parity-audit.bats # ≥22
bash tests/parity/hook-parity-harness.sh             # ≥20
bats tests/structure/test-cross-frontend-invariants.bats # 4
bats tests/structure/test-copilot-cli-compat.bats        # 5

# AC-10
git ls-files .github/hooks/savia.json
```

## Validación empírica adicional pendiente

Test 2 (SessionStart context injection) y Test 3 (agentStop) del runbook no se ejecutaron en la validación original (2026-06-08). Test 1 (PreToolUse blocking) confirmado funcionando. Quedan pendientes de ejecución en una sesión futura con Copilot CLI para sellar al 100%.

## Referencias

- SE-179 (corregida) — `docs/specs/SE-179-copilot-cli-cross-tool-validation.spec.md`
- SE-178 (modelo 4-capas) — `docs/rules/domain/cross-frontend-coverage.md`
- [GitHub Copilot hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration)
- Binario de referencia: `~/.local/share/mise/installs/node/24.16.0/lib/node_modules/@github/copilot/app.js` (Copilot CLI 1.0.60)
