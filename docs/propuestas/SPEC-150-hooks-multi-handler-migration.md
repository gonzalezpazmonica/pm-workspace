---
spec_id: SPEC-150
title: Hooks multi-handler — migrar gates críticos a plugin TS (OpenCode events + composición)
status: PROPOSED
origin: Investigación 2026-05-23 (P3 + F6) + paridad OpenCode. OpenCode v1.14+ expone 25+ eventos en `.opencode/plugin/*.ts` (`tool.execute.before/after`, `chat.message`, `permission.ask`, `event`, `file.edited`, `lsp.*`, etc.). Soporta nativamente 3 de los 5 handler types de Claude Code (command, mcp_tool, prompt vía slash). `http` y `agent` por composición. Savia tiene 65 hooks, todos bash `command`. Deja sobre la mesa el 70% del valor.
severity: Alta — UX y precisión de gates.
effort: ~35h (L) — recalibrado 2026-05-23 tras review: Slice 1 (baseline FP/FN 6 hooks × 100 invocaciones) son 4-6h reales; Slice 5 (`agent` handler experimental) puede salir scope si presupuesto aprieta. Original 24h era agresivo.
priority: P3 — calidad y reducción de falsos positivos.
confidence: media — efecto en producción a validar por hook.
bucket: Q3 2026
related_specs:
  - SPEC-141 (MCP catalog — habilita invocación de MCP tools desde plugins)
  - SPEC-151 (Evals CI — los plugins `prompt` necesitan eval continua)
  - SPEC-142 (Plugin tool.execute.before — primer caso del patrón OpenCode imperativo)
---

# SPEC-150 — Hooks Multi-Handler Migration (OpenCode-native)

## Why

Claude Code 2026 expone 5 handler types declarativos en `settings.json`. **OpenCode tiene paridad PARCIAL**:

| Tipo Claude Code | Equivalente OpenCode | Paridad |
|---|---|---|
| `command` | Plugin TS + `Bun.$` shell, o `opencode run --no-interactive` | FULL (más expresivo) |
| `http` | No nativo — `fetch()` dentro de plugin TS | DIFFERENT (composición) |
| `mcp_tool` | Plugin TS llama tool de MCP server declarado en `opencode.jsonc.mcp` | FULL |
| `prompt` | Slash command (`/<command>`) o LLM call dentro de plugin via SDK | FULL |
| `agent` | `client.session.send()` desde dentro del hook (gap: no first-class, issue [#20387](https://github.com/anomalyco/opencode/issues/20387)) | PARTIAL |

**Eventos OpenCode disponibles** (25+): `tool.execute.before/after`, `chat.message`, `chat.params`, `permission.ask`, `event` (genérico, incluye `session.idle`), `config`, `file.edited`, `file.watcher.updated`, `lsp.client.diagnostics`, `lsp.updated`, `message.*`, `command.executed`, `installation.updated`, `experimental.session.compacting`. Faltan `SessionStart`/`SessionEnd`/`Stop`/`PreCompact` first-class — workaround `event` + filter por `session.idle` (issue [#21075](https://github.com/anomalyco/opencode/issues/21075)).

Los 65 hooks actuales son TODOS bash `command` registrados via `.claude/settings.json`. Esto significa:

- **Privacy-shield / leaks-scan / ban-emojis** son regex bash con falsos positivos (bloquean strings que se parecen a PII pero no lo son).
- **Audit trail** post-edit no llega a ningún storage central (cada commit reinventa anotación).
- **Pre-compact decision** se basa en heurística línea-cuenta, sin entender qué del contexto realmente importa.

Migrar selectivamente los hooks **donde el problema es semántico, no sintáctico**, reduce falsos positivos y desbloquea integraciones (MCP audit log, http SIEM via composición).

## Scope

### Funcional

> **Mapping de eventos Savia ↔ OpenCode** (canon en `docs/rules/domain/hooks-opencode-mapping.md`):
> - Savia `PreToolUse` → OpenCode `tool.execute.before` (mutación imperativa)
> - Savia `PostToolUse` → OpenCode `tool.execute.after`
> - Savia `Stop` → OpenCode `event` con filter `payload.type === "session.idle"`
> - Savia `SessionStart` → OpenCode `event` con filter `payload.type === "session.started"` (cuando esté disponible) o plugin que se ejecuta on-load
> - Savia `UserPromptSubmit` → OpenCode `chat.message` (filter `role === "user"`)
> - Savia `PreCompact` → OpenCode `experimental.session.compacting`

1. **Migrar a "prompt-en-plugin" (Haiku como juez via SDK call)**:
   - `privacy-shield-pretooluse.sh` → plugin TS que en `tool.execute.before` invoca Haiku via `client.completion.create()` para decidir si el path es sensible. Coste estimado: $0.001/turno.
   - `leaks-scan-stop.sh` → plugin TS en `event` (session.idle).
   - `confidentiality-gate.sh` → 2-layer: regex bash en Layer 1 (rápido) + plugin TS Layer 2 con LLM en ambiguos.
   - **Layer 1 regex bloquea claros; Layer 2 plugin con LLM evalúa ambiguos**. Complemento, no reemplazo.

2. **Migrar a `mcp_tool` (invocación desde plugin)**:
   - `audit-trail-posttooluse.sh` → plugin TS en `tool.execute.after` que llama `client.mcp.tools.savia-memory.record_change()` (depende de SPEC-141 stdio MCP exposed).
   - `pre-edit-context-load.sh` → plugin TS en `tool.execute.before` (tool=`edit`) que invoca `knowledge-graph.related_files`.

3. **Migrar a `http` (vía `fetch` en plugin)**:
   - `stop-session-summary.sh` → plugin TS en `event` (session.idle) que hace `fetch("https://savia-hub.local/api/sessions", {method:"POST"})` (si configurado).
   - `pretooluse-rate-limit-warn.sh` → fetch a Slack webhook si OpenCode detecta rate limit crítico.

4. **Migrar a `agent` (experimental, OpenCode partial)**:
   - `prepush-pr-summary.sh` → plugin TS que usa `client.session.send()` para spawn de subagent `pr-agent-judge` desde el hook. Caveat: no es first-class (issue #20387), documentar limitación.
   - Default OFF, opt-in.

5. **Sistemática de migración por hook**:
   - Medir tasa de FP/FN del hook actual con muestra de 100 invocaciones (Slice 1).
   - Si FP+FN ≥ 5% → candidato a migración.
   - Si <5% → mantener `command` (más barato).
   - Implementar la migración manteniendo el bash `command` como fallback (plugin TS falla → cae a regex bash).

6. **Eventos OpenCode que Savia debería usar (no usados hoy)**:
   - `experimental.session.compacting` — decidir qué persistir antes del compact (encaja con context-rot-strategy skill).
   - `permission.ask` — captura para auto-recuperación cuando permisos se deniegan.
   - `lsp.client.diagnostics` — disparar análisis de calidad al guardar.
   - `file.watcher.updated` — re-validar cambios fuera del flujo OpenCode.
   - `command.executed` — telemetría de uso de slash commands.

7. **Convergencia Claude Code legacy**:
   - Mantener hooks bash en `.claude/hooks/` para usuarios todavía en Claude Code.
   - Documentar en `docs/rules/domain/hooks-opencode-mapping.md` que la canon es OpenCode plugin TS; bash es legacy.

### No funcional

- Coste operativo p95: <$0.003/turno extra por hooks `prompt` activos.
- Latencia añadida: hooks `prompt` p95 <800ms (Haiku 4.5 latency).
- Audit log persistente: cada handler emite line en `output/hooks-audit.jsonl`.

## Design

### Estructura

```
.opencode/plugin/                          # canon: OpenCode plugins TS
├── privacy-shield-layer2.ts               # LLM evaluator en tool.execute.before
├── audit-trail.ts                         # invoca mcp_tool savia-memory.record_change
├── session-summary-http.ts                # fetch a SaviaHub en event(session.idle)
└── prepush-pr-summary-agent.ts            # opt-in: client.session.send() para subagent

.claude/hooks/                              # legacy bash, Layer 1 regex + fallback
├── privacy-shield-pretooluse.sh           # regex Layer 1 (rápido, deterministic)
└── ...

opencode.jsonc
└── plugin: ["./plugin/privacy-shield-layer2.ts", ...]   # registro

docs/rules/domain/
├── hooks-handler-policy.md                # cuándo usar cada patrón, anti-patterns
└── hooks-opencode-mapping.md              # Savia events ↔ OpenCode events

scripts/
└── audit-hook-handlers.sh                 # reporta plugins TS instalados + cobertura por evento
```

### Plantilla `privacy-shield-layer2.ts`

```typescript
// .opencode/plugin/privacy-shield-layer2.ts
import { plugin } from "@opencode-ai/plugin";

const FAST_REGEX_CLEAR_PII = /([a-z0-9._-]+)@(gmail|hotmail|yahoo)\.com/i;
const AMBIGUOUS_PATTERN = /[a-z0-9._-]+@[a-z0-9.-]+\.[a-z]{2,}/i;

export default plugin(({ on, client, output }) => {
  on("tool.execute.before", async (event) => {
    if (!["bash", "write", "edit"].includes(event.tool)) return;
    const content = (event.args.command || event.args.content || "") as string;

    // Layer 1: regex fast-path (handled by legacy bash hook before this plugin)
    // This plugin handles Layer 2: ambiguous cases
    if (!AMBIGUOUS_PATTERN.test(content) || FAST_REGEX_CLEAR_PII.test(content)) return;

    // Layer 2: LLM judge (Haiku)
    try {
      const judgment = await client.completion.create({
        model: "haiku",
        max_tokens: 50,
        prompt: `Eval if this text contains REAL PII (real emails, real names) vs example/test data. Return JSON {decision: "allow"|"deny", reason: "..."}. Text: ${content.slice(0, 500)}`,
      });
      const decision = JSON.parse(judgment.text);
      if (decision.decision === "deny") {
        output.abort = `Shield (Layer 2 LLM): ${decision.reason}`;
      }
    } catch (err) {
      // Plugin falla → cae a regex bash legacy en .claude/hooks/
      console.warn("Layer 2 plugin failed, falling back to regex:", err);
    }
  });
});
```

### Tabla de migración (resumen, OpenCode-native)

| Hook savia legacy | Evento OpenCode | Patrón nuevo | Razón |
|------|-------------|------------|-------|
| privacy-shield-pretooluse | `tool.execute.before` | bash regex (Layer 1) + plugin TS LLM (Layer 2) | Falsos positivos en docstrings |
| leaks-scan-stop | `event` (session.idle) | plugin TS con LLM judge | Contexto necesario |
| confidentiality-gate | `tool.execute.before` | regex + plugin TS LLM 2-layer | Defense in depth |
| audit-trail-posttooluse | `tool.execute.after` | plugin TS llamando MCP tool | Centralizar audit via savia-memory MCP |
| stop-session-summary | `event` (session.idle) | plugin TS con `fetch()` | SaviaHub integration |
| prepush-pr-summary | `event` (manual trigger via cmd) | plugin TS con `client.session.send()` | Reuso de pr-agent-judge subagent (gap: issue #20387) |

## Acceptance Criteria

- [ ] AC-01: 6 hooks migrados según tabla, con fallback al `command` legacy bash en cada caso.
- [ ] AC-02: Medición pre/post: FP+FN del plugin TS ≤ 50% del bash legacy en muestra de 50 casos.
- [ ] AC-03: `output/hooks-audit.jsonl` recibe entries del plugin TS + del legacy bash con flag de capa.
- [ ] AC-04: `audit-hook-handlers.sh` reporta cobertura: ≥6 plugins TS instalados, ≥3 eventos OpenCode distintos usados.
- [ ] AC-05: Documentación:
  - `docs/rules/domain/hooks-handler-policy.md` — cuándo usar cada patrón, anti-patterns (eg. "no uses mcp_tool para policy enforcement — si el server cae falla silencioso").
  - `docs/rules/domain/hooks-opencode-mapping.md` — Savia events ↔ OpenCode events.
- [ ] AC-06: Coste real medido en producción ≤$0.005/turno extra (sample de 100 turnos).
- [ ] AC-07: Tests vitest por plugin TS + BATS por hook bash legacy, incluyendo escenario "plugin TS falla → fallback bash legacy activa".
- [ ] AC-08: Plugins registrados en `opencode.jsonc.plugin: [...]` con orden documentado.
- [ ] AC-09: Limitación conocida `agent` handler (issue #20387) documentada con fallback explícito.

## Agent Assignment

- **Capa**: Infrastructure / Quality
- **Agente principal**: `security-guardian` (privacy hooks) + `dev-orchestrator` (audit/http hooks)
- **Skills**: `evaluations-framework` (medir FP/FN), `verification-lattice` (validar comportamiento equivalente)

## Slicing

- **Slice 1** (4h) — Medir FP/FN actual de los 6 hooks candidatos. Si <5% → reconsiderar candidato.
- **Slice 2** (6h) — Migrar `privacy-shield-pretooluse` y `leaks-scan-stop` a `prompt` con fallback.
- **Slice 3** (4h) — Migrar `audit-trail-posttooluse` a `mcp_tool` (depende de SPEC-141 stdio MCP listo).
- **Slice 4** (4h) — Migrar `stop-session-summary` a `http` (SaviaHub endpoint).
- **Slice 5** (3h) — `prepush-pr-summary` a `agent` opt-in.
- **Slice 6** (3h) — Audit script + docs + tests + cobertura PostToolBatch/PreCompact.

## Feasibility Probe

Slice 1 actúa como probe global: si el FP rate actual de los 6 hooks es <2%, el ROI de migración es bajo y solo se hace para 1-2 hooks claros.

## Riesgos

- **Coste descontrolado**: si hooks `prompt` se activan en cada PreToolUse, $0.001 × N turnos × 1000 dev/día → significativo. Mitigación — matcher restrictivo, fallback rápido en case Layer 1 ya decidió.
- **Latencia Haiku**: en momentos pico Haiku puede tardar >2s. Mitigación — timeout 1.5s y fallback a `command`.
- **mcp_tool falla silenciosa**: si el MCP cae, el hook deja de validar. Mitigación — **no usar mcp_tool para policy enforcement**, solo para audit/observability. Doc lo prohíbe.
- **Agent handler experimental**: la API puede cambiar. Mantener opt-in y NO depender de él en gates críticos.
