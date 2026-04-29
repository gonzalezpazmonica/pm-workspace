# Recommendation Tribunal — real-time audit de recomendaciones conversacionales

> **SPEC**: SPEC-125 (`docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md`)
> **Slice**: 1 Foundation (clasificador + 4 jueces + scripts + hook stub). Slice 2 (asymmetric expertise rewrite) y Slice 3 (memory feedback loop) follow-up.
> **Status**: canonical, **NO ACTIVADO POR DEFECTO**. Activación requiere edición humana de `.claude/settings.json` tras revisar el batch completo.
> **Riesgo**: safety-critical — modifica el flow de cada turn cuando se active. Por eso la activación es deliberada y separada del entrega del código.

---

## Tesis (one paragraph)

La cuarta clase de output de Savia — **recomendaciones conversacionales en tiempo real** — fluye sin gate. Truth Tribunal cubre reports (SPEC-106), Code Review Court cubre código pre-merge, reflection-validator opera on-demand. Pero cuando Savia dice "haz X / no hagas Y / el problema es Z" durante un turn, esas frases llegan al usuario sin auditoría. Y son las que más daño hacen porque hay asimetría de expertise: la usuaria razonablemente confía y a menudo no tiene el conocimiento técnico para auditar la recomendación. SPEC-125 cierra esa gap con un panel de 4 jueces rápidos (<3s p95) que intercepta cada draft pre-output y emite verdict `PASS / WARN / VETO`, con banner inline visible y memory feedback loop para calibración sin re-entreno.

---

## Diseño Slice 1 (Foundation)

### Componentes entregados

| Tipo | Path | Rol |
|---|---|---|
| Orchestrator agent | `.claude/agents/recommendation-tribunal-orchestrator.md` | Convoca 4 jueces en paralelo via Task, agrega, aplica vetos, mutates output |
| Judge agent | `.claude/agents/memory-conflict-judge.md` | Detecta contradicción con `~/.claude/external-memory/auto/feedback_*.md` |
| Judge agent | `.claude/agents/rule-violation-judge.md` | Detecta violación de CLAUDE.md / autonomous-safety / radical-honesty |
| Judge agent | `.claude/agents/hallucination-fast-judge.md` | Verifica entidades (paths, fns, flags) con tool calls reales |
| Judge agent | `.claude/agents/expertise-asymmetry-judge.md` | Reescribe output cuando draft cae en área `audit_level: blind` |
| Classifier | `scripts/recommendation-tribunal/classifier.sh` | Heurística primer paso: ¿es una recomendación? ¿qué risk_class? |
| Aggregator | `scripts/recommendation-tribunal/aggregate.sh` | Agrega 4 verdicts deterministicamente, decide PASS/WARN/VETO |
| Banner renderer | `scripts/recommendation-tribunal/banner.sh` | Renderiza markdown banner según verdict |
| Hook stub | `.claude/hooks/recommendation-tribunal-pre-output.sh` | PreOutput hook (NOT activated) — Slice 1 modo detect-only |

### Flujo end-to-end (cuando se active en Slice 2)

```
Savia escribe draft
  ↓
classifier.sh                       ← heurística <50ms, free
  ↓ is_recommendation=true, risk≥medium
Orchestrator (Task tool)
  ↓ paralelo
[memory-conflict] [rule-violation] [hallucination-fast] [expertise-asymmetry]
  ↓ JSON outputs
aggregate.sh                        ← deterministic, no LLM
  ↓ verdict PASS|WARN|VETO
banner.sh                           ← markdown render
  ↓ stdout
Hook delivers (mutated o pass-through)
  ↓
audit JSON persisted en output/recommendation-tribunal/<date>/<hash>.json
```

### Modo Slice 1: detect-only (instrumentación)

El hook `recommendation-tribunal-pre-output.sh` **NO** invoca al orchestrator todavía. Slice 1 entrega:

1. La infraestructura completa (jueces, scripts, orchestrator)
2. El hook **listo para activar** pero NO añadido a `.claude/settings.json`
3. El hook en modo "detect-only": clasifica + persiste audit log + pasa el draft sin mutación

Esto permite:
- Ver qué tasa de recomendaciones se detectan en uso real (calibración del classifier antes de wirear vetos)
- Validar el clasificador heurístico contra un golden set sin riesgo en flow real
- Que la usuaria revise el batch completo antes de la activación irreversible

### Activación (paso humano explícito, post-batch)

Para activar en Slice 2 (cuando la classifier-precision esté validada):

```jsonc
// .claude/settings.json
{
  "hooks": {
    "PreOutput": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/recommendation-tribunal-pre-output.sh"
          }
        ]
      }
    ]
  }
}
```

Y dentro del hook, sustituir el block "passthrough — Slice 1 detect-only" por la invocación real del orchestrator.

### Heurística del classifier

3 niveles, primer match wins:

- **CRITICAL**: bypass / disable / lower threshold / `--no-verify` / force push / desactivar gate. Detecta también equivalentes en español.
- **HIGH**: imperative en dominio risky (sudo, prod deploy, drop table, install, rm -rf).
- **MEDIUM**: te recomiendo, deberías, el problema es, usa la librería, cambia X por Y. Bilingual.
- **LOW** (no match): no es recomendación → tribunal NOT invoked.

Solo `medium+` activa el panel de 4 jueces. Esto evita 95% de turns conversacionales triviales.

### Veto rules (definitivas)

VETO automático cuando:
- Algún juez tiene `veto: true` con `confidence ≥ 0.8`
- `memory-conflict` cita un `feedback_*.md` o `user_*.md`
- `rule-violation` cita Rule #1 / Rule #8 / autonomous-safety / radical-honesty / zero-project-leakage
- `hallucination-fast` reporta ≥1 entidad fabricada con confidence ≥ 0.9 (verificación definitiva, no "podría ser typo")

`expertise-asymmetry` **nunca** veta. Solo muta el output forzando rewrite con secciones explanation / alternatives / verification.

### Latency budget

Hard cap: 3s wall-clock. Si timeout → verdict WARN con razón "timeout" + lo que tengamos. Nunca bloquea el turn por completo.

Distribución esperada (Slice 2 activación):
- classifier.sh: <50ms (heurística pura, no LLM)
- 4 jueces en paralelo: ~800ms (haiku/sonnet con tool calls limitados)
- aggregate.sh + banner.sh: <100ms
- Total p95 target: 1.5-2s

### Audit trail

Cada invocación persiste a `output/recommendation-tribunal/YYYY-MM-DD/<draft_hash>.json` (gitignored — vive en `output/` que ya está fuera del repo público). En Slice 1 detect-only mode, solo el classification se guarda. En Slice 2 con jueces activos, se persiste cada verdict + judge output + final delivered text.

El audit es **append-only**: nunca se sobrescribe. Permite reconstruir post-mortem qué vetos / warns ocurrieron y si fueron justos.

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
- NO implementa el rewrite-blind en producción (Slice 2).
- NO implementa memory feedback loop (Slice 3 — captura de followup turn → feedback memory).
- NO requiere LLM externo. Funciona con la stack actual (haiku + sonnet vía Task tool).
- NO sustituye Truth Tribunal ni Code Review Court ni el code-review humano (E1).
- NO bloquea tool calls. Esos los gobiernan hooks PreToolUse existentes.

---

## Referencias

SPEC-125 (`docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md`).
Pattern sources citados en spec original: Constitutional AI critique (Anthropic 2024-2025), G-Eval Inline (OpenAI Evals 2026), DeepEval streaming (confident-ai 2026).
