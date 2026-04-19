---
id: SPEC-049
title: SPEC-049: Depth-Adjustable Review
status: Proposed
origin_date: "2026-03-30"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-049: Depth-Adjustable Review

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: garagon/nanostack research — Intelligence Modes (Quick/Standard/Thorough)
> Impacto: Reviews proporcionales al riesgo, ahorro de tokens en PRs triviales

---

## Problema

`/pr-review` siempre ejecuta al mismo nivel de profundidad independientemente
de si el PR es un typo fix de 3 lineas o un refactor de autenticacion de 500.
Consecuencias:

- PRs triviales consumen el mismo contexto y tiempo que PRs criticos
- PRs criticos no reciben scrutinio adicional a menos que se escale manualmente
- El modelo usado es siempre el mismo (no hay escalamiento por riesgo)
- No hay correlacion entre el risk score existente y la profundidad del review

Nanostack resuelve esto con 3 "intelligence modes" (Quick/Standard/Thorough)
que ajustan la profundidad de inspeccion por riesgo. pm-workspace tiene el
risk-scoring skill y risk-escalation.md pero no los conecta con /pr-review.

---

## Arquitectura

### Flag: --depth quick|standard|thorough

```
/pr-review {PR} --depth quick       # Haiku, checklist rapido
/pr-review {PR} --depth standard    # Sonnet, review completo (default)
/pr-review {PR} --depth thorough    # Opus, review exhaustivo + security
/pr-review {PR}                     # Auto-detect via risk score
```

### Mapeo depth ↔ risk score ↔ modelo

| Depth | Risk Score | Modelo | Perspectivas | Tiempo |
|-------|-----------|--------|-------------|--------|
| quick | 0-25 | Haiku | 2 (code, format) | ~30s |
| standard | 26-50 | Sonnet | 4 (code, security, perf, spec) | ~2min |
| thorough | 51-100 | Opus | 5 (code, security, perf, spec, arch) | ~5min |

### Auto-detection (sin flag explicito)

Si el PM no especifica `--depth`, Savia calcula el risk score del PR
usando el skill `risk-scoring` y selecciona el depth automaticamente:

```
1. Obtener diff del PR (files changed, lines changed)
2. Invocar risk-scoring skill → score 0-100
3. Mapear score a depth segun tabla
4. Mostrar banner: "Risk score: 34 → depth: standard (Sonnet)"
5. Ejecutar review al nivel seleccionado
```

### Perspectivas por depth

| Perspectiva | quick | standard | thorough |
|------------|:-----:|:--------:|:--------:|
| Code quality + Format/lint | x | x | x |
| Security (OWASP, secrets) | | x | x |
| Performance + Spec compliance | | x | x |
| Architecture + Consensus* | | | x |

*Consensus solo si risk score >75 (Critical en risk-escalation.md)

---

## Integracion

### Con risk-scoring skill

El skill ya calcula un score 0-100 basado en 8 factores. La unica
modificacion es invocar el skill al inicio de `/pr-review` cuando
no se especifica `--depth` explicitamente.

### Con risk-escalation.md

Los thresholds se alinean con los 4 tiers existentes:

| risk-escalation Tier | Depth mapping |
|---------------------|---------------|
| Low (0-25) | quick |
| Medium (26-50) | standard |
| High (51-75) | thorough |
| Critical (76-100) | thorough + consensus |

### Con consensus-protocol.md

En depth `thorough` con risk score >75, el review se eleva
automaticamente a consensus-validation (3-judge panel).
Esto ya existe en el protocolo pero no se activaba desde pr-review.

### Con pr-plan (Rule #25)

`/pr-plan` muestra depth estimado en su output: `G8 — Review depth: standard (risk 34)`.

### Con model escalation (pm-config.md)

quick → CLAUDE_MODEL_FAST, standard → CLAUDE_MODEL_MID, thorough → CLAUDE_MODEL_AGENT.

---

## Restricciones

- El PM siempre puede override con `--depth` explicito
- Security PRs (detected by file patterns: auth, crypto, secrets)
  tienen depth minimo `standard` aunque el risk score sea bajo
- El depth NO afecta a las reglas REJECT de code-review-rules.md
  (secrets, merge markers, debugger statements se detectan SIEMPRE)
- Budget de contexto: quick max 4K, standard max 12K, thorough max 25K
- El risk score se calcula UNA vez por PR, no por fichero

---

## Implementacion por fases

### Fase 1 — Flag explicito (~1h)
- [ ] Modificar pr-review.md: aceptar --depth, 3 niveles de perspectivas
- [ ] Seleccionar modelo segun depth. Test: mismo PR en 3 depths

### Fase 2 — Auto-detection (~1h)
- [ ] Integrar risk-scoring skill al inicio de pr-review
- [ ] Mapear score a depth, mostrar banner. Test: trivial→quick, critico→thorough

### Fase 3 — Consensus + Metricas (~30min)
- [ ] thorough + risk >75 activa consensus-validation automaticamente
- [ ] Tracking: distribucion depths, tokens por nivel, override rate

---

## Ficheros afectados

| Fichero | Accion |
|---------|--------|
| `.claude/commands/pr-review.md` | Modificar — flag --depth + auto-detect |
| `.claude/commands/pr-plan.md` | Modificar — mostrar depth estimado |
| `docs/rules/domain/risk-escalation.md` | Sin cambios (ya tiene thresholds) |

---

## Metricas de exito

- Tokens consumidos en reviews de PRs triviales: reduccion >50%
- PRs criticos sin review thorough: 0% (auto-detection los atrapa)
- Override rate del PM: <15% (auto-detection es preciso)
- Tiempo medio de review quick: <45s
