---
spec_id: SPEC-127
title: Savia ↔ OpenCode + GitHub Copilot Enterprise compatibility — provider-agnostic foundation
status: PROPOSED
origin: User authorization (2026-04-30) — empresa autoriza usar Savia con OpenCode + GitHub Copilot Enterprise. Audit técnico revela 3 categorical breaks que impiden parity sin reroute.
severity: Crítica — sin spec, adopción Copilot empieza con ~75% de Savia roto
effort: ~80h (5 slices) — Slice 1 mínimo viable, Slices 2-5 incrementales
priority: P0 — desbloquea pivote a Copilot autorizado, evita re-trabajo masivo
related_specs:
  - SE-077 (OpenCode v1.14 replatform — IMPLEMENTED 2026-04-26, ~70% del trabajo Claude-OpenCode hecho)
  - SE-055 (.opencode parity generator — superseded por este spec)
  - SE-078 (sovereignty-switch — complementary)
  - SPEC-122 (LocalAI emergency hardening — complementary fallback)
  - SPEC-SE-001 (Layer Contract — IMPLEMENTED 2026-04-30, foundation)
related_rules:
  - .claude/rules/domain/autonomous-safety.md
  - .claude/rules/domain/zero-project-leakage.md
---

# SPEC-127: Savia ↔ OpenCode + GitHub Copilot Enterprise compatibility

## Tesis (one paragraph)

Mónica acaba de obtener autorización corporativa para usar Savia con OpenCode conectada a GitHub Copilot Enterprise. SE-077 (batch 2026-04-26) construyó el puente OpenCode v1.14 con Claude Max como backend — ese trabajo cubre **~70%** de Savia bajo OpenCode-Claude. Pero Copilot Enterprise es un vector distinto: **tres breaks categóricos** que no existen con OpenCode-Claude (zero hook surface en Copilot, no subagent fan-out, no slash command mechanism), más cuatro fricciones operativas (compaction 400 #11157, premium request inflation #8030, context cap 128K, GHE on-prem auth requiere plugin externo). El audit revela que de los componentes críticos (64 hooks, 71 agentes, 90 skills, 534 comandos, 65 hook-event registrations en `settings.json`), solo skills (90) son ~95% portables tal cual. El resto requiere capa de adaptación. **Esta spec NO promete parity completo** — declara explícitamente qué se pierde bajo Copilot y cómo se reroutea (MCP server para commands, git pre-commit + CI para enforcement layer que pierde hooks, single-shot fallback para orchestrators que pierden Task delegation).

---

## El problema en una frase

Pasar de Claude Code a OpenCode-Copilot Enterprise rompe ~75% de los enforcement layers de Savia silenciosamente — los tests siguen pasando porque corren contra el árbol de archivos, no contra el comportamiento real bajo Copilot.

---

## Evidencia (del audit técnico 2026-04-30)

### Counts del workspace actual

| Categoría | Total | Claude Code-specific | OpenCode portable | Copilot portable |
|---|---:|---:|---:|---:|
| Hooks (`.claude/hooks/*.sh`) | 64 | 46 (`CLAUDE_PROJECT_DIR`) | ~50 (vía adapter shim ya implementado) | ~5 (sin hook surface) |
| Settings.json hook entries | 65 | 65 | Plugin TS port | 0 (sin hook events) |
| Agents (`.claude/agents/*.md`) | 71 | 70 declaran model claude-X | 70 con alias map | 70 con alias map (con caveat) |
| Skills (`SKILL.md`) | 90 | 0 | ~95% native | ~95% native |
| Commands (`.claude/commands/*.md`) | 534 | 534 | Partial port | 0 (sin slash commands) |
| Tool_input parsing hooks | 26 | 26 | OK vía run-hook.sh shim | Broken (sin telemetría provider) |

### Top 10 archivos por execution weight (real flow)

1. `.claude/settings.json` (cada hook invocation)
2. `.claude/hooks/session-init.sh` (cada session)
3. `.claude/hooks/validate-bash-global.sh` (cada Bash call)
4. `.claude/hooks/block-credential-leak.sh` (cada Bash/Edit)
5. `.claude/hooks/tdd-gate.sh` (cada code edit)
6. `.claude/hooks/responsibility-judge.sh` (cada PreToolUse)
7. `.claude/hooks/block-gitignored-references.sh` (cada Edit/Write)
8. `.claude/hooks/agent-dispatch-validate.sh` (cada Task call)
9. `.claude/agents/dev-orchestrator.md` (entry point orquestación)
10. `CLAUDE.md` (5 `@import`s — cada turn)

### Las 5 fricciones críticas confirmadas en docs/issues OpenCode 2026

1. **Compaction 400 Bad Request** ([Issue #11157](https://github.com/anomalyco/opencode/issues/11157)) — Copilot Enterprise rechaza messages con `role:"tool"` durante compaction. Bloquea sesiones largas. Sin workaround documentado.
2. **Hooks bash → TS plugin port** — OpenCode v1.14 NO parsea `.claude/settings.json` hooks (Issue #12472). Plugin SDK TS expone `tool.execute.before`/`tool.execute.after` pero `matcher: "Edit|Write"` y `$CLAUDE_PROJECT_DIR` NO son nativos.
3. **Premium request inflation** ([Issue #8030](https://github.com/anomalyco/opencode/issues/8030)) — tool attachments generan "user" messages sintéticos que consumen premium reqs. Caso: 60 reqs en una sesión, medio quota mensual quemada.
4. **Context cap 128K** ([Issue #5993](https://github.com/anomalyco/opencode/issues/5993)) — Copilot provider impone límite aunque el modelo soporte 256K+. Savia hoy usa 1M en Claude.
5. **GHE on-prem auth** ([Issue #3936](https://github.com/anomalyco/opencode/issues/3936), [PR #2522](https://github.com/sst/opencode/pull/2522)) — github.com out-of-the-box; GHE on-prem requiere plugin externo. Verificación pendiente sobre stack concreto de la empresa.

### Los 3 categorical breaks vs OpenCode-Claude

| Capacidad | OpenCode-Claude | OpenCode-Copilot |
|---|---|---|
| Hook events surface | Plugin TS expone ~25 eventos | **Cero** — Copilot no expone tool-call telemetry al cliente |
| Subagent fan-out (Task tool) | Soportado con `task_budget` | **No soportado** — Copilot no tiene Task delegation |
| Workspace slash commands | Parcial (`.opencode/commands/`) | **Cero** — Copilot no tiene slash command mechanism |

Estos tres breaks NO se arreglan con un adapter shim — requieren reroute arquitectónico.

---

## Solución: 5 slices de adaptación incremental

### Slice 1 (S, 8h) — Provider-agnostic foundation

**Objetivo**: minimum viable para arrancar OpenCode-Copilot sin que Savia se rompa de inmediato. Aprovecha el ~70% que SE-077 ya hizo.

Artefactos:
- `docs/rules/domain/provider-agnostic-env.md` — canonical env vars: `SAVIA_WORKSPACE_DIR` (fallback chain `CLAUDE_PROJECT_DIR` → `OPENCODE_PROJECT_DIR` → `git rev-parse --show-toplevel` → `pwd`).
- `scripts/savia-env.sh` — single-source loader que exporta env vars normalizadas. Source desde cualquier hook.
- `docs/rules/domain/model-alias-table.md` — mapping table:
  ```
  claude-sonnet-4-6     → github-copilot/claude-opus-4.7  (primary)
                       → github-copilot/gpt-5.5            (fallback)
  claude-opus-4-7       → github-copilot/claude-opus-4.7
                       → github-copilot/o1                 (fallback)
  claude-haiku-4-5-20251001 → github-copilot/gpt-5.5-mini
  ```
  Tabla en doc, NO patch de los 70 agentes en source — resolución en runtime.
- `scripts/agents-md-auto-regenerate.sh` — extender el existente para producir `.github/copilot-instructions.md` además de `AGENTS.md`. Trinity CLAUDE.md / AGENTS.md / copilot-instructions.md desde una sola source-of-truth.
- BATS tests sobre los 4 archivos.

Acceptance criteria Slice 1:
- AC-1.1: cada hook que use `CLAUDE_PROJECT_DIR` puede source `savia-env.sh` y obtener `SAVIA_WORKSPACE_DIR` con fallback funcional bajo OpenCode shell.
- AC-1.2: model-alias-table.md documenta 3 mappings primarios + fallback con razón.
- AC-1.3: regenerator produce `.github/copilot-instructions.md` válido (max 120 lines, no `@import`s — Copilot no los soporta).

### Slice 2 (M, 16-20h) — Copilot hook adapter + TS plugin port (top 10)

**Objetivo**: trasplantar los 10 hooks más críticos a un equivalente que funcione bajo Copilot Enterprise (que NO tiene hook surface). Reroute via git pre-commit + plugin TS para los que tengan equivalente, y honest-fail para los que no.

Artefactos:
- `.opencode/plugins/savia-critical-hooks.ts` — Plugin TS que implementa los hooks de top 10 que tengan equivalente directo:
  - `validate-bash-global.sh` → `tool.execute.before` matcher Bash
  - `block-credential-leak.sh` → `tool.execute.before` matcher Bash + Edit
  - `block-gitignored-references.sh` → `tool.execute.before` matcher Edit + Write
  - `responsibility-judge.sh` → `tool.execute.before` matcher Edit + Write
  - `tdd-gate.sh` → `tool.execute.before` matcher Edit
- Para Copilot Enterprise (sin hook surface): mover lo que NO se puede TS-portear a `.husky/` (git pre-commit) que corre antes de `git commit`. Caveat: solo intercepta cambios commiteados, no edits intermedios.
- `scripts/copilot-portability-classifier.sh` — clasifica cada hook en TIER:
  - **TIER-1 portable**: TS plugin equivalente directo (top 10)
  - **TIER-2 git-pre-commit**: rerouteable vía .husky
  - **TIER-3 ci-only**: solo en GitHub Actions (no real-time)
  - **TIER-4 lost**: no portable bajo Copilot — declarar pérdida explícita
- BATS tests para classifier + plugin TS skeleton.

Acceptance criteria Slice 2:
- AC-2.1: los 10 hooks top execution-weight tienen plan de portabilidad explícito (TIER-1/2/3/4).
- AC-2.2: ≥5 hooks top-10 portados a TIER-1 (TS plugin) con tests.
- AC-2.3: `prompt-injection-guard`, `block-credential-leak` cubiertos en TIER-1 o TIER-2 — son safety-critical.
- AC-2.4: clasificación de los 64 hooks documentada en `output/copilot-hook-portability-classification.md`.

### Slice 3 (M, 12-16h) — Slash command MCP shim

**Objetivo**: Copilot no tiene slash command mechanism. 534 commands de Savia perderían descubribilidad. Reroute via MCP server.

Artefactos:
- `scripts/savia-commands-mcp-server.ts` (Node/TS) — expone los 534 commands como MCP tools. Cada `.claude/commands/<name>.md` se traduce a un MCP tool con:
  - `name: savia_<name>`
  - `description:` extraído del frontmatter
  - `inputSchema:` derivado del cuerpo del command
  - `execute:` ejecuta el bash equivalente o invoca el sub-skill
- `docs/rules/domain/savia-commands-mcp.md` — registry contract + cómo añadir/remover commands.
- Configuración MCP server en `.opencode/mcp.json` y plantilla para `~/.config/opencode/mcp.json`.
- BATS tests sobre el server (subset de 10 commands canary).

Acceptance criteria Slice 3:
- AC-3.1: MCP server arranca y expone ≥50 commands (tier 1 batch).
- AC-3.2: 10 commands canary (sprint-status, daily-plan, savia-status, etc.) ejecutables vía MCP desde OpenCode-Copilot.
- AC-3.3: Si admin Copilot Enterprise pone "Registry only" para MCP, doc pivot a publicar el server en marketplace MS-curated o degradación documentada.

### Slice 4 (M, 8-12h) — Subagent fallback (single-shot mode)

**Objetivo**: Copilot no tiene Task tool / subagent fan-out. Los orchestrators de Savia (`recommendation-tribunal-orchestrator`, `truth-tribunal-orchestrator`, `court-orchestrator`, `dev-orchestrator`) asumen subagent delegation. Sin fallback, fallan silenciosamente.

Artefactos:
- `docs/rules/domain/subagent-fallback-mode.md` — patrón "single-shot expanded prompt": cuando no hay Task, el orchestrator inserta el prompt del agent target en su propio context y produce su output como una sub-sección. Pierde aislamiento de context, pero mantiene la lógica.
- Patch de 4 orchestrators críticos para detectar `SAVIA_PROVIDER=copilot` y pivotar a single-shot.
- `scripts/savia-provider-detect.sh` — detecta provider activo y exporta `SAVIA_PROVIDER` env var.
- Regression test: cada orchestrator produce el mismo veredicto-shape bajo Claude (con Task) y Copilot (single-shot) sobre 3 fixture inputs.

Acceptance criteria Slice 4:
- AC-4.1: 4 orchestrators críticos detectan `SAVIA_PROVIDER` y pivotan.
- AC-4.2: Single-shot mode preserva el JSON output schema del orchestrator (audit trail compatible).
- AC-4.3: BATS tests verifican equivalencia funcional sobre 3 inputs por orchestrator.

### Slice 5 (S, 6h) — Premium request guard + budget tracker

**Objetivo**: Issue #8030 quema quota Copilot mensual en horas. Savia bajo Copilot necesita visibilidad y guard rails antes de acabar la cuota a las 11AM.

Artefactos:
- `scripts/copilot-quota-tracker.sh` — wrapper que cuenta premium requests por sesión usando log de OpenCode + heurística de tool attachments.
- `.claude/hooks/copilot-budget-guard.sh` — PreToolUse (en Claude) o `tool.execute.before` (en OpenCode plugin) que warns cuando consumo del día > 70% del budget mensual / 22 días.
- Integración con `cognitive-debt.sh summary` para mostrar quota Copilot junto a horas Claude-active.
- Tests BATS sobre tracker.

Acceptance criteria Slice 5:
- AC-5.1: tracker detecta tool attachment patterns que inflan premium reqs.
- AC-5.2: budget guard avisa (no bloquea) al 70%, 85%, 95% del budget mensual.
- AC-5.3: integración con `/cognitive-status` muestra quota.

---

## Lo que esta spec NO hace (declaración explícita)

- **NO promete parity completa con Claude Code bajo Copilot Enterprise.** Tres capacidades se pierden estructuralmente: subagent fan-out (Task tool), workspace slash commands, hook events real-time PreToolUse. Las 3 se reroutean (single-shot, MCP, git pre-commit) pero el reroute tiene costes funcionales documentados.
- **NO migra los 534 commands a TS plugins.** Demasiado coste vs valor incremental — MCP server cubre el 90% de uso real.
- **NO arregla compaction 400** (#11157) — es bug upstream de OpenCode + Copilot, fuera de scope. Workaround: limitar context a 100K efectivos, sesiones cortas.
- **NO sustituye Claude Max como frontend principal.** Copilot Enterprise es plan B operativo + cumplimiento corporativo. Cuando Mónica está fuera de la corporate VPN, Claude Max sigue funcionando en local.
- **NO portea hooks que dependen de Anthropic-specific telemetry** sin un equivalente Copilot. Si no existe el equivalente, el hook se declara TIER-4 lost y se documenta la pérdida.
- **NO modifica el modelo de Savia subyacente** — solo capa de adaptación. El comportamiento intrínseco de los agentes es independiente del provider.

---

## Restricciones inviolables

- **PV-01**: ningún cambio de Slice 1-5 puede romper la operación actual de Savia bajo Claude Code. Backward compat absoluto.
- **PV-02**: las 3 capas de seguridad críticas (`block-credential-leak`, `prompt-injection-guard`, `block-gitignored-references`) deben tener cobertura equivalente en OpenCode-Copilot — TIER-1 obligatorio. Si no se puede, el spec se bloquea.
- **PV-03**: los datos sensibles confidenciales (PII, credenciales, hardware specs) NO pueden exfiltrarse al provider Copilot. La capa shield (`ANTHROPIC_BASE_URL` proxy) debe extenderse a Copilot endpoints.
- **PV-04**: el opt-in es per-comando: `SAVIA_PROVIDER=copilot` en el environment. Por defecto, Savia sigue corriendo en Claude Max.
- **PV-05**: cualquier hook que pase a TIER-4 (lost) requiere alerta documentada en `docs/cognitive-debt-guide.md` o equivalente — la pérdida de seguridad debe ser visible, no silenciosa.

---

## Plan por fases (resumen)

| Slice | Effort | Bloquea | Acceptance gate |
|---|---|---|---|
| 1 — Foundation | 8h | nada | env layer + alias table + AGENTS/copilot-instructions trinity |
| 2 — Hook adapter | 16-20h | Slice 1 | top 10 hooks portados / clasificados |
| 3 — Command MCP shim | 12-16h | Slice 1 | MCP server + 50+ commands tier 1 |
| 4 — Subagent fallback | 8-12h | Slices 1-3 | 4 orchestrators con single-shot mode |
| 5 — Premium quota guard | 6h | Slice 1 | tracker + warnings 70/85/95% |

**Total: ~50-62h de trabajo real**, en 5 PRs. Slice 1 desbloquea operación básica. Slices 2-5 son enhancement incremental — Mónica puede operar después de Slice 1 con caveats explícitos.

---

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Mónica empieza a usar OpenCode-Copilot ANTES de Slice 1 → enforcement layer roto silencioso | Alta | Crítico | Slice 1 es bloqueante absoluto. Sin él, `block-credential-leak` no corre, riesgo de leak de PAT real |
| Empresa de Mónica usa GHE on-prem (no github.com) → auth roto | Media | Alto | Slice 1 incluye verificación + plugin externo si aplica |
| Compaction 400 (#11157) hace sesiones largas inviables | Alta | Medio | Documentar context budget 100K + sesiones cortas. Alternative: Slice 5 alarms |
| Premium quota se quema antes de Slice 5 ship | Alta | Medio | Slice 5 priorizar tras Slice 1 si Mónica entra a Copilot heavy |
| MCP server (Slice 3) bloqueado por "Registry only" del admin Enterprise | Media | Alto | Slice 3 incluye plan B: degradación a comandos directos por chat o publicación en marketplace |
| Tests pasan en Claude pero rompen en Copilot silenciosamente | Alta | Alto | BATS smoke con `SAVIA_PROVIDER=copilot` mock para detectar discrepancias antes de ship |
| Subagent single-shot mode produce outputs distintos a Claude Task | Alta | Medio | Slice 4 incluye fixture comparison test (3 inputs × 4 orchestrators) |

---

## Dependencias

- **Bloquea**: nada técnicamente, pero cualquier feature nueva post-2026-04-30 debería respetar el provider-agnostic env layer (no añadir más `CLAUDE_PROJECT_DIR` hardcodeados).
- **Habilita**:
  - Adopción real de Copilot Enterprise por equipos que lo usan
  - Plan B operativo verdadero (no solo el SE-077 con Claude Max backend)
  - Sovereignty completa — Savia funciona en cualquier provider supported por OpenCode
- **Sinergia**:
  - SE-077 OpenCode v1.14 replatform — este spec lo extiende a Copilot
  - SPEC-122 LocalAI emergency — Copilot es otro tier en el fallback chain
  - SPEC-SE-001 Layer Contract — extensión del contrato Core ↛ Enterprise se aplica a OpenCode/Copilot también

---

## Decisiones pendientes para el humano

1. **Stack GHE concreto**: ¿la empresa usa github.com (GHEC) o GHE on-prem? Determina si hace falta plugin externo en Slice 1.
2. **Modelos disponibles en el tier Copilot Enterprise concreto**: lista exacta (GPT-5.5 GA confirmado, Claude Opus 4.7 hasta 30-abr-2026, GPT-5-Codex; otros pendientes). Determina las model-aliases primary/fallback en Slice 1.
3. **MCP policy del tenant Enterprise**: "Allow all" vs "Registry only". Si "Registry only", Slice 3 pivota a publicación en marketplace MS-curated.
4. **Premium request budget mensual**: cuántos premium reqs tiene el contract? Determina umbrales del Slice 5 (70/85/95%).
5. **Sovereignty switch policy**: ¿Mónica quiere `SAVIA_PROVIDER=copilot` per-sesión o per-tarea? Determina granularidad de Slice 4.

---

## Métricas de éxito (medibles, no aspiracionales)

Tras Slice 1 ship + 30 días en producción real:

- **Cobertura hook portability**: ≥80% de los top-10 hooks ejecutándose bajo Copilot (TIER-1 + TIER-2)
- **Quota premium consumption**: <50% de la quota mensual contratada por Mónica usada en operación normal
- **Zero leaks**: 0 instancias de credenciales o PII pasadas al provider Copilot vs al shield (auditoría con `confidentiality-scan.sh`)
- **Subagent fallback fidelity**: >85% de equivalencia funcional entre Claude (con Task) y Copilot (single-shot) sobre 12 fixture inputs (3 × 4 orchestrators)
- **Zero silent breaks**: ningún hook TIER-4 (lost) falla sin alerta visible

---

## Referencias

### Research output (2026-04-30)

- [GitHub Changelog 2026-01-16 — OpenCode support](https://github.blog/changelog/2026-01-16-github-copilot-now-supports-opencode/)
- [OpenCode Providers docs](https://opencode.ai/docs/providers/)
- [OpenCode Plugins docs](https://opencode.ai/docs/plugins/)
- [OpenCode Agent Skills docs](https://opencode.ai/docs/skills/)
- [OpenCode Agents docs](https://opencode.ai/docs/agents/)
- [Issue #11157 — Compaction 400 con Copilot Enterprise](https://github.com/anomalyco/opencode/issues/11157)
- [Issue #8030 — Premium request inflation](https://github.com/anomalyco/opencode/issues/8030)
- [Issue #5993 — Context cap 128K](https://github.com/anomalyco/opencode/issues/5993)
- [Issue #3936 — GHE on-prem auth](https://github.com/anomalyco/opencode/issues/3936)
- [Issue #12472 — Native hooks compat](https://github.com/anomalyco/opencode/issues/12472)
- [PR #2522 — GHE Copilot support plugin](https://github.com/sst/opencode/pull/2522)
- [Configure MCP server access enterprise](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-mcp-usage/configure-mcp-server-access)
- [Copilot Premium Requests Billing](https://docs.github.com/en/billing/concepts/product-billing/github-copilot-premium-requests)
- [Copilot Supported AI Models Enterprise](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/ai-models/supported-models)

### Audit interno Savia 2026-04-30

- 64 hooks, 71 agentes, 90 skills, 534 commands, 65 hook event registrations
- 626 occurrences de Claude-specific env vars
- Top 10 hooks por execution weight identificados (en sección "Evidencia")

### Specs relacionadas

- SE-077 OpenCode v1.14 replatform (IMPLEMENTED 2026-04-26)
- SE-055 .opencode parity generator (PROPOSED, **superseded por este spec**)
- SE-078 sovereignty-switch
- SPEC-122 LocalAI emergency hardening
- SPEC-SE-001 Layer Contract (IMPLEMENTED 2026-04-30)

---

## Aprobación

Tras revisión humana → arrancar **Slice 1 (Foundation, 8h)** que es bloqueante para operar Copilot con seguridad mínima. Slices 2-5 son incrementales, priorizados según uso real:
- Si Mónica empieza heavy en Copilot → Slice 5 (premium quota guard) primero
- Si Mónica usa subagents heavy (court-review, recommendation-tribunal) → Slice 4 antes de Slice 3
- Si Mónica usa slash commands heavy en chat → Slice 3 antes de Slice 4

**Honest assessment**: este spec tendrá ~50-62h de trabajo real. SE-077 hizo 70% del trabajo Claude-OpenCode. Para Copilot Enterprise solo cubre ~25% — los tres categorical breaks (no hooks, no Task, no slash) son nuevos y requieren reroute arquitectónico, no shim.

## Implementation Plan (OpenCode-ready) — SPEC-127 ::: classification: full

### Plan resumen

5 slices secuenciales con Slice 1 (Foundation) bloqueante absoluto. Slices 2-5 priorizables según uso real de Mónica. Cada slice deja Savia operacional incrementalmente bajo Copilot Enterprise sin romper operación bajo Claude Code.

### Slice 1 — Foundation (8h, ~batch 87)

Provider-agnostic env layer + model alias table + trinity CLAUDE.md/AGENTS.md/copilot-instructions.md desde single source. Aprovecha SE-077 que ya hizo 70% del trabajo Claude-OpenCode. Sin Slice 1, Mónica entrar a Copilot rompe enforcement layer silencioso.

Decisión clave: `SAVIA_WORKSPACE_DIR` con fallback chain en lugar de patchear 46 hooks. Single source touched.

### Slice 2 — Hook adapter + TS plugin port (16-20h, ~batch 88-89)

TS plugin que portea los 10 hooks top execution-weight a OpenCode events. Para los que no tienen equivalente: reroute a `.husky/` (git pre-commit) o declarar TIER-4 lost.

Decisión clave: `prompt-injection-guard` y `block-credential-leak` SON safety-critical — TIER-1 obligatorio o el slice se bloquea.

### Slice 3 — Slash command MCP shim (12-16h, ~batch 90)

MCP server que expone 534 commands como MCP tools. Pivot a "Registry only" si admin Enterprise lo restringe.

### Slice 4 — Subagent fallback single-shot (8-12h, ~batch 91)

4 orchestrators críticos con single-shot mode cuando `SAVIA_PROVIDER=copilot`. Preserva audit trail JSON shape.

### Slice 5 — Premium quota guard (6h, ~batch 92)

Tracker + warnings 70/85/95%. Integra con `/cognitive-status`.

### Riesgo de implementación más alto

Slice 1 mal diseñado → patches subsiguientes en cascada. Mitigación obligatoria: el `savia-env.sh` debe ser source-able sin side effects, con fallbacks puros (no llama a `gh api` ni `git` pesado en hot path), y testeado bajo 3 environments (Claude Code, OpenCode-Claude, OpenCode-Copilot mock).
