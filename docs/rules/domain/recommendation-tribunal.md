# Recommendation Tribunal — real-time audit de recomendaciones conversacionales

> **SPEC**: SPEC-125 (`docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md`)
> **Slice**: 1 Foundation. Slice 2 (asymmetric expertise rewrite + activación) y Slice 3 (memory feedback loop) follow-up.
> **Status**: canonical, **NO ACTIVADO POR DEFECTO**. Activación = edición humana de `.claude/settings.json` tras revisar el batch.
> **Riesgo**: safety-critical — modifica el flow de cada turn cuando se active.

---

## Tesis (one paragraph)

La cuarta clase de output de Savia — **recomendaciones conversacionales en tiempo real** — fluye sin gate. Truth Tribunal cubre reports (SPEC-106), Code Review Court cubre código pre-merge, reflection-validator opera on-demand. Pero cuando Savia dice "haz X / no hagas Y / el problema es Z" durante un turn, esas frases llegan al usuario sin auditoría. Y son las que más daño hacen porque hay asimetría de expertise: la usuaria razonablemente confía y a menudo no tiene el conocimiento técnico para auditar la recomendación. SPEC-125 cierra esa gap con un panel de 4 jueces rápidos (<3s p95) que intercepta cada draft pre-output y emite verdict `PASS / WARN / VETO`, con banner inline visible y memory feedback loop para calibración sin re-entreno.

---

## Componentes Slice 1 (Foundation)

| Tipo | Path | Rol |
|---|---|---|
| Orchestrator | `.opencode/agents/recommendation-tribunal-orchestrator.md` | Convoca 4 jueces en paralelo via Task, agrega, aplica vetos, mutates output |
| Judge (memory) | `.opencode/agents/memory-conflict-judge.md` | Detecta contradicción con `feedback_*.md` / `user_*.md` |
| Judge (rules) | `.opencode/agents/rule-violation-judge.md` | Detecta violación de CLAUDE.md / autonomous-safety / radical-honesty |
| Judge (halluc) | `.opencode/agents/hallucination-fast-judge.md` | Verifica entidades (paths, fns, flags) con tool calls reales |
| Judge (expert) | `.opencode/agents/expertise-asymmetry-judge.md` | Reescribe output cuando draft cae en área `audit_level: blind` |
| Classifier | `scripts/recommendation-tribunal/classifier.sh` | Heurística primer paso: ¿es una recomendación? ¿qué risk_class? |
| Aggregator | `scripts/recommendation-tribunal/aggregate.sh` | Agrega 4 verdicts deterministicamente |
| Banner | `scripts/recommendation-tribunal/banner.sh` | Renderiza markdown banner según verdict |
| Hook stub | `.opencode/hooks/recommendation-tribunal-pre-output.sh` | PreOutput hook (NOT activated) — detect-only |

---

## Flujo end-to-end (cuando se active en Slice 2)

```
Savia draft
  ↓ classifier.sh (<50ms, sin LLM)
  ↓ is_recommendation=true, risk≥medium
Orchestrator (Task tool) — 4 jueces en paralelo
  ↓ JSON outputs
aggregate.sh (deterministic) → verdict PASS|WARN|VETO
  ↓ banner.sh (markdown)
Hook delivers (mutated o passthrough)
  ↓ audit JSON en output/recommendation-tribunal/<date>/<hash>.json
```

---

## Modo Slice 1: detect-only

El hook **NO** invoca al orchestrator todavía. Slice 1 entrega:

1. La infraestructura completa (jueces + scripts + orchestrator)
2. El hook **listo para activar** pero NO añadido a `.claude/settings.json`
3. Modo "detect-only": clasifica + persiste audit log + pasa el draft sin mutación

Permite calibrar el classifier en uso real antes de wirear vetos. La usuaria revisa el batch completo antes de la activación irreversible.

---

## Activación (paso humano explícito post-batch)

En Slice 2 — cuando la classifier-precision esté validada — añadir a `.claude/settings.json` un hook PreOutput con `matcher: *` que invoque `$CLAUDE_PROJECT_DIR/.opencode/hooks/recommendation-tribunal-pre-output.sh`. Y dentro del hook, sustituir el block "passthrough — Slice 1 detect-only" por la invocación real del orchestrator.

---

## Heurística del classifier

3 niveles, primer match wins:

- **CRITICAL**: bypass / disable / lower threshold / hook-skip flags / force push / desactivar gate. Bilingüe (inglés + español).
- **HIGH**: imperative en dominio risky (sudo, prod deploy, drop table, install, rm -rf).
- **MEDIUM**: te recomiendo, deberías, el problema es, usa la librería, cambia X por Y. Bilingüe.
- **LOW** (no match): no es recomendación → tribunal NOT invoked.

Solo `medium+` activa el panel. Esto evita ~95% de turns conversacionales triviales.

---

## Veto rules (definitivas)

VETO automático cuando:
- Algún juez tiene `veto: true` con `confidence ≥ 0.8`
- `memory-conflict` cita un `feedback_*.md` o `user_*.md`
- `rule-violation` cita Rule #1 / Rule #8 / autonomous-safety / radical-honesty / zero-project-leakage
- `hallucination-fast` reporta ≥1 entidad fabricada con confidence ≥ 0.9 (verificación definitiva, no "podría ser typo")

`expertise-asymmetry` **nunca** veta. Solo muta el output forzando rewrite con secciones explanation / alternatives / verification.

---

## Latency budget

Hard cap: 3s wall-clock. Si timeout → verdict WARN con razón "timeout" + lo que tengamos. Nunca bloquea el turn por completo.

Distribución esperada (Slice 2 activación): classifier <50ms, 4 jueces paralelos ~800ms, aggregate+banner <100ms. **Target p95: 1.5-2s**.

---

## Audit trail

Cada invocación persiste a `output/recommendation-tribunal/YYYY-MM-DD/<draft_hash>.json` (gitignored — vive en `output/` fuera del repo público). En Slice 1 detect-only, solo classification. En Slice 2 con jueces activos, cada verdict + judge output + final delivered text.

Append-only: nunca se sobrescribe. Permite reconstruir post-mortem qué vetos / warns ocurrieron y si fueron justos.

---

## Cross-refs

- **SPEC-125** — spec original
- **SPEC-106** — Truth Tribunal (sibling, cubre reports async)
- **CLAUDE.md** — Rule #1, Rule #8, Rule #24
- **`docs/rules/domain/autonomous-safety.md`** — eje de rule-violation-judge
- **`docs/rules/domain/radical-honesty.md`** — eje de rule-violation-judge
- **`~/.claude/external-memory/auto/`** — fuente del memory-conflict-judge

---

## No hace (esta Slice)

- NO activa el hook por defecto. Activación = edición humana de `.claude/settings.json` post-revisión.
- NO implementa el rewrite-blind real en producción (Slice 2).
- NO implementa memory feedback loop (Slice 3 — captura de followup turn → feedback memory).
- NO requiere LLM externo. Funciona con la stack actual (haiku + sonnet vía Task tool).
- NO sustituye Truth Tribunal ni Code Review Court ni el code-review humano (E1).
- NO bloquea tool calls. Esos los gobiernan hooks PreToolUse existentes.

---

## Referencias

SPEC-125 (`docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md`). Pattern sources: Constitutional AI critique (Anthropic 2024-2025), G-Eval Inline (OpenAI Evals 2026), DeepEval streaming (confident-ai 2026).
