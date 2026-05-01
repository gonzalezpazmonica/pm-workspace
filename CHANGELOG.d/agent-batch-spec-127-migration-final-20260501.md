---
version_bump: minor
section: Added
---

### Added

#### SPEC-127 Slice 2b-ii — última entrega bajo Claude Code, OpenCode listo para migrar

Esta es la última PR que se entrega corriendo bajo Claude Code. Tras su merge, el operador arranca con OpenCode v1.14.30 como frontend principal y Savia opera provider-agnostic (PV-06).

- **5 hooks TIER-1 portados a TypeScript** (`.opencode/plugins/`):
  - `validate-bash-global.ts` — bloquea 6 patrones globales (`rm -rf /`, `chmod 777`, `curl|bash`, `gh pr review --approve`, `gh pr merge --admin`, `sudo`).
  - `block-credential-leak.ts` — detecta 13 tipos de credencial (Anthropic/OpenAI/AWS/GitHub/Google API keys, Azure conn strings/SAS, Vault tokens, K8s service-account tokens, claves privadas, docker passwords, PATs, secretos genéricos).
  - `block-gitignored-references.ts` — bloquea referencias a destinos privados salvo desde fuentes self-referencing legítimas (tests, código del propio hook).
  - `prompt-injection-guard.ts` — detecta 10 patrones override (block) + 5 sociales (warn-only) + zero-width chars + comentarios HTML ocultos. Skip de archivos de código por defecto.
  - `tdd-gate.ts` — exige test-first para código de producción. Helper `tddGateForPath` testable sin filesystem.
  - Cada hook tiene su `*.test.ts` con block + edge cases. Foundation plugin (`savia-foundation.ts`) los encadena vía dispatcher `tool.execute.before`. PV-02 safety-critical preservado.

- **Helpers compartidos** (`.opencode/plugins/lib/`):
  - `hook-input.ts` — extracción defensiva de tool name/command/file_path/content (devuelve `""` ante datos faltantes).
  - `credential-patterns.ts` — registro de 13 patterns de credencial con `detectCredentialLeak(command)`.
  - `leakage-patterns.ts` — patterns construidos vía concatenación dinámica para evitar self-detection del propio hook.
  - `injection-patterns.ts` — `detectInjection(content)` con verdict block/warn.
  - Todos con suite de tests unitarios.

- **`scripts/agents-opencode-convert.sh`** — converter de agentes Claude Code → OpenCode v1.14:
  - `tools: [Read, Bash]` → `tools: { read: true, bash: true }` (inline array y YAML list).
  - `color: lime` → `color: "#9ACD32"` (mapa 18 named colors).
  - Modos: default print / `--apply` / `--check` (idempotente).
  - PV-06: NO traduce nombres de modelo (passthrough). El runtime resuelve via preferencias del operador.
  - Resultado: 70 agentes convertidos en `.opencode/agents/`. `opencode debug config` ahora reporta 70 agentes (antes 0 por schema mismatch).

- **`docs/migration-claude-code-to-opencode.md`** — guía de migración paso a paso (≤150 líneas):
  - Qué se preserva / qué se pierde (con honestidad radical).
  - 7 pasos numerados: upgrade binario → preferences init → agents converter --apply → smoke test → debug config → real run → budget guard opcional.
  - Rollback en una línea.
  - Troubleshooting de los 4 errores típicos.

- **`scripts/opencode-migration-smoke.sh`** — 6 checks fast-fail:
  1. Binario `opencode ≥ 1.14.0`.
  2. `opencode.json` válido JSON.
  3. ≥70 agentes discoverable.
  4. ≥500 commands discoverable.
  5. `SKILLS.md` con ≥50 entries.
  6. 8 archivos de plugin foundation presentes.
  - Exit 0 = ready to migrate. PASS=6 FAIL=0 WARN=0 en workspace canónico.

- **`savia-budget-guard` registrado en `.claude/settings.json`** — PreToolUse `*` con timeout 5s. Hook nunca bloquea (only warns 70/85/95% del presupuesto mensual). Bajo OpenCode, mismo guard via plugin foundation. Bajo Claude Code, via `.sh` hook nativo.

- **`scripts/cognitive-debt.sh`** — `cmd_summary` integra resumen mes-a-fecha del quota tracker (Slice 5 + 2b-ii). El operador ve cognitive metrics + presupuesto Savia en una sola salida.

- **`tests/structure/test-spec-127-migration-final.bats`** — 43 tests cubriendo todos los componentes (5 ports + helpers + foundation + converter + budget-guard + onboarding + smoke + cognitive-debt). Auditor: certified (92).

#### Spec status

- `slice_2b_ii_status: IMPLEMENTED 2026-05-01`.
- `slice_3_status: NOT_NEEDED` — OpenCode v1.14 tiene discovery nativo de slash commands via `.opencode/commands/` symlink. No hace falta porting.
- AC-2.2 marcada como implementada.

#### CLAUDE.md drift

- Bumped `hooks(65/65reg)` → `hooks(65/66reg)` para reflejar registro de `savia-budget-guard`.

#### Notas

- **Era 189 (OpenCode)** — esta PR cierra la era Claude Code. La siguiente PR ya se trabaja desde OpenCode bootstrapped.
- **Provider-agnostic (PV-06)** — ningún archivo nuevo hardcodea Anthropic/Claude/Sonnet/Opus/Haiku. Verificado por test BATS dedicado.
- **Backward compat (PV-01)** — todos los `.sh` originales siguen vivos. Esta PR añade archivos, NO modifica los hooks `.claude/hooks/*.sh`.
- **Investigación BitNet** entregada como informe interno gitignored. Spec/PR no creados — autonomous-safety: investigación NO crea backlog sin aprobación humana.

Refs: SPEC-127.
