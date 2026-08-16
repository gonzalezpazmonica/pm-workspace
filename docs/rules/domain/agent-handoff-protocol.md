---
context_tier: L3
token_budget: 1150
usage: reference-only
dormant_since: "2026-06-24"
review_note: "Quarterly review 2026-Q2"
---

# Agent Handoff Protocol — SPEC-121

> Convención **handoff-as-function** para transiciones entre agentes en pipelines SDD. Inspirado en OpenAI Agents SDK.

## Cuándo usar cuál protocolo

| Situación | Protocolo | Documento canónico |
|---|---|---|
| Handoff simple E1→E2→E3 con artefactos claros | **handoff-as-function** (este doc) | `agent-handoff-protocol.md` |
| Research multi-turn, decisión compleja, discusión | **agent-notes longform** | `docs/agent-notes-protocol.md` |
| Broadcasting a múltiples agentes | **agent-notes longform** | `docs/agent-notes-protocol.md` |

**Regla**: si el handoff cabe en 7 campos, usa handoff-as-function. Si necesitas párrafos, usa agent-notes.

## Formato canónico

Al final del output de un agente, si necesita pasar el control a otro agente, añade un bloque YAML `handoff:`:

```yaml
---
handoff:
  to: code-reviewer              # Agent canonical name (required)
  spec: SPEC-120                 # Spec reference (required)
  stage: E2                      # SDD stage E0..E4 (required)
  context_hash: sha256:abc123... # SHA-256 of prior state (required)
  reason: "Implementation ready" # Short reason (required, ≤80 chars)
  termination_reason: completed  # Enum (required): completed | user_abort | token_budget | stop_hook | max_turns | unrecoverable_error
  artifacts:                     # Files produced (optional)
    - docs/propuestas/SPEC-120.md
    - .opencode/skills/.../spec-template.md
---
```

## Campos

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `to` | string (agent name) | sí | Nombre canónico del agente destino (debe existir en `.opencode/agents/`) |
| `spec` | string | sí | Referencia spec (SPEC-NNN, PBI-NNN, AB#id) |
| `stage` | string | sí | Etapa SDD: `E0`..`E4` |
| `context_hash` | string | sí | SHA-256 hex prefix del estado previo (determinístico) |
| `reason` | string (≤80 chars) | sí | Motivo conciso del handoff |
| `termination_reason` | enum | sí | Estado de cierre — compatible con validator existente |
| `artifacts` | list[string] | no | Rutas relativas a ficheros producidos |

## Reglas

1. **to** debe ser un agente declarado en `.opencode/agents/*.md`. Validator rechaza agentes desconocidos.
2. **context_hash** debe calcularse con `sha256sum` sobre el concat ordenado de artifacts + spec + reason. Permite detectar drift.
3. **stage** debe progresar monotónicamente en una serie (no E2→E1 sin razón documentada).
4. **artifacts** son paths relativos al `REPO_ROOT`, sin `./` inicial.
5. Handoff con `termination_reason` ≠ `completed` **no activa** al agente destino automáticamente — requiere resolución humana.

## Handback (SE-332) — escalación reference-first

Instancia autónoma **bloqueada** que escala a su padre (Handback Obligation,
`autonomous-safety.md`) NO usa `handoff:` canónico (que activa al destino) — emite
artifact `handback:` **reference-first** (solo rutas, nunca cuerpo), permitiendo retomar
sin re-derivar contexto.

```yaml
---
handback:
  escalado_desde: overnight-sprint        # modo | agente que escaló (required)
  escalado_a: "@monica"                   # padre resuelto por handback-resolve.sh (required)
  motivo: guardrail_rechazo               # recurso_no_disponible | guardrail_rechazo | modelo_mismatch | otro
  contexto_ref:                           # reference-first — rutas, no contenido (required, ≥1)
    - output/agent-runs/overnight-20260816-fix-x/run-record.jsonl
    - output/loop-state/overnight-20260816-fix-x/terminal-state.jsonl
  intentos_restantes: 2
  timestamp: "2026-08-16T07:25:00Z"
---
```

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `escalado_desde` | string | sí | Modo o agente que emite el handback |
| `escalado_a` | string | sí | Padre resuelto por `scripts/handback-resolve.sh` |
| `motivo` | enum | sí | `recurso_no_disponible` \| `guardrail_rechazo` \| `modelo_mismatch` \| `otro` |
| `contexto_ref` | list[string] | sí | Rutas a artifacts (run-record, terminal-state.jsonl). PROHIBIDO eco de cuerpo |
| `intentos_restantes` | int | no | Reintentos de modelo restantes |
| `timestamp` | string | sí | ISO-8601 de la escalación |

**Reglas**: (1) `escalado_a` lo resuelve `handback-resolve.sh` — no a mano; (2) `contexto_ref`
son paths relativos al `REPO_ROOT` sin `./`; el orquestador reanuda leyendo esos artifacts;
(3) a diferencia de `handoff:` `completed`, el `handback` **no activa** al destino — requiere
resolución humana explícita y registra `handback_to` en el audit trail.

## Validación

Validación con `scripts/validate-handoff.sh --file handoff.yaml`:

```bash
$ bash scripts/validate-handoff.sh --file examples/handoff-ok.yaml
OK

$ bash scripts/validate-handoff.sh --file examples/handoff-bad.yaml
ERROR: to='nonexistent-agent' not found in .opencode/agents/
```

Exit codes:
- `0` — handoff válido
- `1` — warning (campo opcional falta)
- `2` — inválido (rechaza)

## Ejemplo completo

```yaml
---
handoff:
  to: code-reviewer
  spec: SPEC-120
  stage: E2
  context_hash: sha256:48c18e5132b873e849021f804799374ce84814ac1590ff8ae9aa4307b216037d
  reason: "SPEC-120 spec-kit alignment implementation ready"
  termination_reason: completed
  artifacts:
    - .opencode/skills/spec-driven-development/references/spec-template.md
    - docs/agent-teams-sdd.md
    - tests/test-spec-template-compliance.bats
---
```

## Relación con agent-notes-protocol.md

Ambos coexisten: **handoff-as-function** (este doc) para transiciones rápidas
estructuradas; **agent-notes-protocol** para threads longform multi-turn. Un agente
PUEDE producir ambos: agent-notes con análisis + handoff YAML con destino. El
orquestador lee primero `handoff:` (routing); las notes son contexto secundario.

## Integración con autonomous-safety.md

- Los handoffs de agentes en ramas `agent/*` NO pueden tener `to: merge-bot` ni similares.
- `termination_reason` distinto de `completed` **bloquea** la cadena — requiere humano (AUTONOMOUS_REVIEWER).
- `artifacts` fuera de `agent/*` branch son sospechosos y logeados en audit trail.

## Referencias

- [OpenAI Agents SDK](https://github.com/openai/openai-agents-python) — patrón original
- `docs/agent-notes-protocol.md` — protocolo longform complementario
- `scripts/validate-handoff.sh` — validator
- SPEC-121 — docs/propuestas/SPEC-121-handoff-convention.md
