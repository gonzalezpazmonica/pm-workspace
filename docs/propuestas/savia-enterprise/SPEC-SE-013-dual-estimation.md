# SPEC-SE-013 — Dual Estimation Rule (Human + Agent Pipeline)

> **Priority:** P1 · **Estimate (human):** 1d · **Estimate (agent):** ~1h · **Type:** planning + measurement

## Objective

Dar a la PM visibilidad realista del tiempo agéntico vs. humano en la planificación de specs, y documentar el claim empíricamente defendible de pm-workspace: **"10x throughput end-to-end con supervisión humana sobre el pipeline completo asistido por agentes"**.

Hoy todos los specs del workspace se estiman en días-persona (`Estimate: Nd`). El tiempo agéntico real de implementación es 1-2 órdenes de magnitud menor, pero la PM no tiene el dato cuando planifica. Resultado: sprints sub-utilizados, ondas de entrega mal dimensionadas, y un claim de producto ("pm-workspace = 10x") que vive solo como intuición.

Este spec formaliza la regla, la aplica al template, mide los specs completados en `agent-actuals.jsonl`, y permite recalibrar los ratios con datos del propio workspace tras 10-30 specs.

## Principles affected

- **#3 Honestidad radical** — el 10x se claim con condiciones explícitas y medición, no como marketing
- **#5 El humano decide** — los ratios asisten la planificación, no sustituyen al PM
- **#7 Protección de la identidad propia** — el speedup se mide con supervisión humana, nunca en autonomía total

## Design

### El claim

```
pm-workspace multiplica la capacidad del equipo por ~10x sobre el
pipeline end-to-end cuando se adopta el workflow completo asistido
por agentes:

  discovery + spec writing + implementation + review + PM
```

El 10x NO es velocidad pura de agente picando código (que oscila entre 0.84x y 150x según el "bar of done"). Es el speedup realista del **pipeline completo con supervisión humana en todos los puntos de decisión**.

### Desglose por fase

| Fase | Sin pm-workspace (humano solo) | Con pm-workspace (humano asistido por agentes) | Ganancia |
|---|---|---|---|
| Análisis / discovery | 2-4h | + `business-analyst`, product-discovery → 0.5-1h | ~3x |
| Redacción spec | 2-4h | + `sdd-spec-writer` + consensus validation → 0.5-1h | ~4x |
| Implementación | 1-5d | `{lang}-developer` en subagent fresco → 30-90 min | ~15-30x |
| Review | 2-4h | Humano + `code-reviewer` pre-filtro + E1 gate → 0.5-1.5h | ~3x |
| PM / sprint mgmt | 3-5h/sprint | sprint-status, capacity, board-flow → 0.5-1h | ~5x |
| **Coordinación** (meetings, handoffs, context loss) | 20-30% del total | <10% — agentes mantienen contexto en disco | elimina ~20% waste |

**Cuenta end-to-end honesta** (PBI típico de 5d humano):
```
Sin pm-workspace:  2 + 3 + 40 + 4 + 4 + 10 = 63h reloj
Con pm-workspace:  0.5 + 1 + 1 + 1 + 1 + 2 = 6.5h reloj
Speedup real:      ~9.7x ≈ 10x
```

### Fórmula y tabla de ajuste

**Baseline (general rule):**
```
agent_hours ≈ human_days
```
Shorthand mental: *"1 día humano = ~1 hora agente"*. Equivale a 8x (8h humano / 1h agente) — el redondeo a 10x absorbe el review overhead y el waste de coordinación.

**Ajuste fino por categoría** (opcional, cuando el PM necesita precisión):

| Categoría | Multiplier sobre baseline | Speedup efectivo | Cuándo aplicar |
|---|---|---|---|
| **Trivial** | ×1.5 | **15x** | Hook, config, rename, CHANGELOG entry, one-file script |
| **Standard** | ×1.0 | **10x** (default) | CRUD + tests, bugfix con regression, feature mediana |
| **Complex** | ×0.7 | **7x** | Multi-módulo, refactor, new service con schema |
| **Novel / Research** | ×0.5 | **5x** | Patrón nuevo, dominio desconocido, requisitos ambiguos |
| **Legacy modification** | ×0.2 | **2x** o menos | Código maduro con constraints ocultas (regla METR 2025-07) |

### Condiciones del 10x

El 10x se cumple si y solo si el equipo:

1. **Adopta el workflow completo.** Saltarse `sdd-spec-writer` = perder 3x en la fase spec. Saltarse dev-session-protocol = perder 15x en impl.
2. **Confía en los agentes con supervisión de puntos de decisión.** Re-revisar el 100% del output "por si acaso" mata el 3x de review. Confiar ciegamente sin E1 gate rompe la calidad.
3. **Trabaja en scope apto.** Greenfield + specs claras + código no-legacy. Legacy con constraints ocultas es 2x máximo, independientemente de pm-workspace.
4. **Mide.** Sin datos empíricos el 10x es fe. Con `agent-actuals.jsonl` es dato defendible.

Equipos con adopción parcial: **2-5x** (honesto).
Equipos con adopción total + scope favorable: **10x o más** (defendible).

### Components

| Name | Kind | Purpose |
|---|---|---|
| `.claude/rules/domain/dual-estimation.md` | rule | Documentación del claim + tabla + fórmula + condiciones + protocolo de tracking |
| `docs/propuestas/TEMPLATE.md` | template | Añadir `Estimate (human): Nd` y `Estimate (agent): Nh` al header de specs |
| `scripts/estimate-calibrate.sh` | script | Recomputa ratios empíricos desde `agent-actuals.jsonl` y sugiere ajustes |
| `data/agent-actuals.jsonl` | data (gitignored) | Seed con SE-001/002/008/012 + entradas HUDI del experimento + template |
| `tests/test-dual-estimation.bats` | test | Valida formato de la regla, fórmulas del script, integridad del JSONL |
| `docs/propuestas/savia-enterprise/DEVELOPMENT-PLAN.md` | docs update | Header con el 10x claim + enlace a la regla |

### Contracts

**Fórmula canonical:**
```
agent_hours(category, human_days) =
  human_days × base_multiplier[category]
  where base_multiplier = { trivial: 0.533, standard: 0.8, complex: 1.143,
                            novel: 1.6, legacy: 4.0 }
```
(Salen de dividir `8h/speedup` para cada categoría: `8/15=0.533`, `8/10=0.8`, etc.)

**Template de spec con dual estimate:**
```markdown
> **Priority:** P0|P1|P2 · **Estimate (human):** Nd · **Estimate (agent):** Nh · **Category:** trivial|standard|complex|novel|legacy · **Type:** category
```

**Schema de `data/agent-actuals.jsonl` (append-only):**
```json
{
  "spec_id": "SE-XXX",
  "category": "standard",
  "human_estimate_days": 5,
  "agent_estimate_hours_predicted": 5.0,
  "agent_wallclock_hours_actual": 1.25,
  "human_review_hours_actual": null,
  "rework_cycles": 0,
  "verdict": "shipped|shipped-with-fixes|abandoned",
  "commit_sha": "abc123",
  "completed_at": "2026-04-11T20:30:00Z"
}
```

**`scripts/estimate-calibrate.sh` output:**
```
$ bash scripts/estimate-calibrate.sh
Samples: 12 (trivial: 3, standard: 6, complex: 2, novel: 1, legacy: 0)
Empirical speedup by category:
  trivial:  18.2x  (current default: 15x)   → suggest ×1.8
  standard: 22.4x  (current default: 10x)   → suggest ×2.2
  complex:  8.1x   (current default: 7x)    → close enough
  novel:    4.7x   (current default: 5x)    → close enough
  legacy:   —      (insufficient data)
Global pipeline speedup (weighted): 14.6x
Recommendation: keep 10x as headline claim (conservative), update table if samples > 30.
```

### Configuration

- Añadido a `pm-config.md`:
  - `DUAL_ESTIMATION_ENABLED = true`
  - `DUAL_ESTIMATION_MIN_SAMPLES = 10` (umbral para auto-sugerir recalibración)
  - `AGENT_ACTUALS_LOG = "data/agent-actuals.jsonl"`

## Acceptance criteria

1. **Regla existe:** `.claude/rules/domain/dual-estimation.md` documenta fórmula, tabla, condiciones, protocolo de tracking. ≤150 líneas.
2. **Template actualizado:** `docs/propuestas/TEMPLATE.md` incluye `Estimate (human)` y `Estimate (agent)` en el header. La línea del top del template refleja dual estimate.
3. **Script de calibración:** `scripts/estimate-calibrate.sh` lee `data/agent-actuals.jsonl`, agrupa por categoría, calcula speedup empírico, compara contra defaults y recomienda ajustes. Usa `jq`, falla elegante sin datos.
4. **Seed de datos:** `data/agent-actuals.jsonl` contiene al menos 4 entradas reales (SE-001, SE-002, SE-008, SE-012) con wall-clock estimado conservadoramente, + 2 entradas HUDI del experimento. Fichero en `.gitignore`.
5. **Tests BATS:** `tests/test-dual-estimation.bats` ≥ 10 tests cubriendo:
   - Regla existe con secciones requeridas
   - Template tiene campos dual estimate
   - Script corre sin errores con seed data
   - Script calcula speedup correctamente para caso conocido
   - Script maneja JSONL vacío sin crashes
   - Script maneja categoría sin samples (skip gracefully)
   - Fórmulas matemáticas correctas
   Score SPEC-055 ≥ 80.
6. **DEVELOPMENT-PLAN header** actualizado con el 10x claim + enlace a la regla.
7. **CHANGELOG 4.42.0** con entrada Added + compare link.
8. **pr-plan pasa** 11/11 gates. PR creado en draft → merge con review humana.

## Out of scope

- Retrofit de SPEC-SE-001..012 con `Estimate (agent):` (follow-up, PR separado)
- Dashboard visual de calibración (queda en CLI)
- Tracking automático desde git log (se requeriría parser; manual JSONL append es suficiente v1)
- Incluir review humano como campo medido (el user lo deja para experimento posterior)

## Dependencies

- **Blocked by:** ninguna. Regla independiente.
- **Blocks:** retrofit estimaciones duales en specs existentes (follow-up), marketing claim "10x end-to-end" (necesita este spec para ser defendible).

## Migration path

Reversible trivialmente:
- Rollback = borrar la regla y revertir el template. Los specs existentes siguen teniendo `Estimate: Nd` clásico.
- Activación feature-flag en `pm-config.md` (`DUAL_ESTIMATION_ENABLED`). Si `false` → el template sigue aceptando el formato antiguo; el script no recomputa.

## Impact statement

Este spec convierte el "10x con pm-workspace" de intuición en claim defendible con medición empírica. Tras 10-30 specs completados con tracking, el ratio real del equipo sustituye los defaults y el claim se valida (o se ajusta) con datos propios, no con literatura.

La PM gana visibilidad realista del tiempo agéntico al planificar sprints. El equipo gana un claim de producto honesto. El workspace gana un loop de auto-calibración.

## Sources referenced in the rule

- METR "Measuring AI Ability to Complete Long Tasks" (arxiv 2503.14499, rev. 2026-02)
- METR RCT 2025-07: "Measuring Impact of Early-2025 AI on Experienced OSS Developers" (arxiv 2507.09089) — la única RCT con -19% slowdown en legacy repos
- METR MirrorCode 2026-04-10: greenfield reimplementation desde spec detallada, speedup 10-50x
- Experimento propio n=2 en Apache HUDI (HUDI-8865: 21x, HUDI-8551: 30x ajustado), `output/dual-estimation-experiment/`
- Datos internos pm-workspace: SE-002 (5d humano → ~1.25h agent = ~32x en primer draft)
