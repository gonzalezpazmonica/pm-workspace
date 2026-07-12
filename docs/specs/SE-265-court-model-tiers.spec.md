# Spec: SE-265 — Court model tier assignment (gentle-ai v2.0 inspired)

**Status:** PROPOSED
**Fecha:** 2026-07-12
**Area:** Code Review Court / Model economics / Quality-cost tradeoff
**Branch:** agent/se265-court-model-tiers
**Estimacion:** ~3h
**Inspirado por:** gentle-ai v2.0.0 per-dimension model assignment

**Developer Type:** agent-single
**Asignado a:** claude-agent
**Estado:** Pendiente

**Effort Estimation (Dual Model):**
| Dimension | Value |
|---|---|
| Agent effort | 3h |
| Human effort | 1h |
| Review effort | 30min |
| Context risk | low |
| Agent-capable | yes |
| Fallback | Modificar court-orchestrator + rules YAML |

---

## Origen

gentle-ai v2.0.0 (2026-07-11) introduce "configurable OpenCode review models":
asignacion independiente de modelo para 5 dimensiones de review (risk,
readability, reliability, resilience, refuter). Savia ya adapto el bounded
review y los content-bound receipts de v1.49 (SE-260). Este patron es nuevo:
permite optimizar coste ejecutando dimensiones criticas en modelos pesados
y dimensiones auxiliares en modelos ligeros.

## Problema actual

El Court lanza 5 jueces en paralelo, todos sobre el mismo modelo. Esto
maximiza calidad pero tambien coste. No hay razon para que `cognitive-judge`
(naming, logs, debuggability) consuma el mismo presupuesto de tokens que
`security-judge` (OWASP, injection, credentials).

## Diseño

**`rules/court.rules.yaml`** gana seccion `models`:

```yaml
models:
  default: mid
  per_judge:
    security-judge: heavy
    correctness-judge: heavy
    architecture-judge: mid
    cognitive-judge: fast
    spec-judge: fast
  budget:
    max_total_tokens: 24000
    per_judge_min_tokens: 2000
```

El court-orchestrator lee esta config y asigna el modelo correspondiente
a cada juez al invocarlo via Task tool.

### Safety invariants

- `security-judge` y `correctness-judge` usan `heavy` por defecto (no
  degradable sin revision humana).
- `spec-judge` puede usar `fast` porque verifica ACs contra spec (tarea
  estructurada, no requiere deep reasoning).
- `cognitive-judge` puede usar `fast` porque naming/complexity son
  patrones reconocibles.
- Cualquier override manual requiere entrada en `per_judge`.
- Fallback: si un modelo no esta disponible, se usa el `default`.

### Candidate-causal findings (bonus)

Los findings del Court incluyen campo opcional `causal_chain`:

```yaml
findings:
  - id: F-001
    severity: high
    judge: security-judge
    description: "SQL injection en UserService.GetUser"
    causal_chain:
      - "UserService.GetUser concatena input a query SQL (line 42)"
      - "El input viene de req.params.id sin sanitizar (line 38)"
      - "Un atacante puede injectar ' OR 1=1 --' (demostrado en test)"
    recommendation: "Usar parametros bind de Dapper"
```

Esto hace los findings mas accionables y mas dificiles de disputar.

## Acceptance criteria

AC-1. `rules/court.rules.yaml` tiene seccion `models` con `per_judge` mapping.
AC-2. Court-orchestrator lee la config y asigna modelo por juez.
AC-3. `security-judge` y `correctness-judge` usan `heavy` por defecto.
AC-4. `cognitive-judge` y `spec-judge` usan `fast` por defecto.
AC-5. Coste total del Court medido antes/despues: reduccion >=20% en tokens
       sin aumentar falsos negativos (mismo PR de referencia).
AC-6. Fallback a `default` si modelo configurado no disponible.
AC-7. Findings incluyen `causal_chain` opcional con >=1 paso.

## Ficheros

| Accion | Path |
|--------|------|
| MODIFY | `rules/court.rules.yaml` (añadir seccion models) |
| MODIFY | `.opencode/agents/court-orchestrator.md` (leer model config) |
| CREATE | `tests/test-se-265-court-models.bats` |

## Esfuerzo

3h — cambio de config + modificacion minima en orquestador + tests.
