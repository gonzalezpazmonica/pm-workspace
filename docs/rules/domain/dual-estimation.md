# Dual Estimation Rule (SE-013)

> **pm-workspace = ~10x throughput end-to-end con supervision humana sobre el pipeline completo asistido por agentes.**

## Claim

pm-workspace multiplica la capacidad del equipo por ~10x sobre el pipeline
end-to-end cuando se adopta el workflow completo asistido por agentes:
discovery + spec writing + implementation + review + PM.

El 10x NO es velocidad pura de agente picando codigo (entre 0.84x y 150x segun
el "bar of done"). Es el speedup realista del pipeline completo con supervision
humana en todos los puntos de decision.

## Desglose por fase

| Fase | Humano solo | Con pm-workspace (humano + agentes) | Ganancia |
|---|---|---|---|
| Analisis / discovery | 2-4h | `business-analyst` + product-discovery → 0.5-1h | ~3x |
| Redaccion spec | 2-4h | `sdd-spec-writer` + consensus validation → 0.5-1h | ~4x |
| Implementacion | 1-5d | `{lang}-developer` en subagent fresco → 30-90 min | ~15-30x |
| Review | 2-4h | Humano + `code-reviewer` pre-filtro + E1 gate → 0.5-1.5h | ~3x |
| PM / sprint mgmt | 3-5h/sprint | sprint-status, capacity, board-flow → 0.5-1h | ~5x |
| Coordinacion | 20-30% del total | <10% (contexto en disco) | elimina ~20% waste |

**Cuenta end-to-end honesta** (PBI tipico de 5d humano):
```
Sin pm-workspace:  2 + 3 + 40 + 4 + 4 + 10 = 63h reloj
Con pm-workspace:  0.5 + 1 + 1 + 1 + 1 + 2 = 6.5h reloj
Speedup real:      ~9.7x ≈ 10x
```

## Dos ratios simultaneos: conservative + empirical

La regla mantiene **dos valores vivos** que el PM elige segun contexto:

| Ratio | Valor | Fuente | Cuando usar |
|---|---|---|---|
| **Conservative** (`conservative_ratio`) | **10x fijo** | Literatura + experimento HUDI n=2 + datos iniciales | Default para planning. Siempre seguro. Si el agente va mas rapido, el PM gana; si va mas lento, no queda en ridiculo. |
| **Empirical** (`empirical_ratio`) | **Se actualiza con datos** | `scripts/estimate-calibrate.sh` sobre `data/agent-actuals.jsonl` | Opt-in. Cuando el PM confia en los datos de su equipo (>=10 samples) y quiere estimar en base a experiencia real. |

**Regla crítica:** el `empirical_ratio` NUNCA reemplaza al `conservative_ratio`
automaticamente. El PM DECIDE cuando aplicar empirical via `--mode empirical` en
`scripts/estimate-convert.sh`. El conservative sigue siendo el default de la
planificación de sprint.

## Formula canonica

```
# Conservative (default)
agent_hours = human_days * 0.8    # = human_days * (8h / 10x)

# Empirical (opt-in)
agent_hours = human_days * (8h / empirical_speedup)
```

Shorthand mental (conservative): *"1 dia humano ≈ 1 hora agente"*. Equivale a
8x (8h humano / 1h agente) — el redondeo a 10x absorbe review overhead y waste
de coordinacion.

## Conversor rapido

```
bash scripts/estimate-convert.sh 5                          # 5 human-days, conservative
bash scripts/estimate-convert.sh 5 --mode empirical         # usa ratio del equipo
bash scripts/estimate-convert.sh 5 --category trivial       # aplica x1.5
bash scripts/estimate-convert.sh 5 --format json            # JSON parseable
```

Si `--mode empirical` se pide pero hay < `DUAL_ESTIMATION_MIN_SAMPLES`, el script
avisa y cae al conservative por seguridad.

## Tabla de ajuste por categoria

| Categoria | Multiplier | Speedup efectivo | Cuando aplicar |
|---|---|---|---|
| **Trivial** | ×1.5 | **15x** | Hook, config, rename, CHANGELOG entry, one-file script |
| **Standard** | ×1.0 | **10x** (default) | CRUD + tests, bugfix con regression, feature mediana |
| **Complex** | ×0.7 | **7x** | Multi-modulo, refactor, new service con schema |
| **Novel / Research** | ×0.5 | **5x** | Patron nuevo, dominio desconocido, requisitos ambiguos |
| **Legacy modification** | ×0.2 | **2x** o menos | Codigo maduro con constraints ocultas (METR 2025-07) |

Base multipliers (`8h / speedup_efectivo`):
```
{ trivial: 0.533, standard: 0.8, complex: 1.143, novel: 1.6, legacy: 4.0 }
```

## Condiciones del 10x

El 10x se cumple si y solo si el equipo:

1. **Adopta el workflow completo.** Saltarse `sdd-spec-writer` pierde 3x en
   spec. Saltarse dev-session-protocol pierde 15x en impl.
2. **Confia en los agentes con supervision de puntos de decision.** Re-revisar
   el 100% del output mata el 3x de review. Confiar ciegamente sin E1 gate
   rompe la calidad.
3. **Trabaja en scope apto.** Greenfield + specs claras + codigo no-legacy.
   Legacy con constraints ocultas es 2x maximo, independientemente de pm-workspace.
4. **Mide.** Sin datos empiricos el 10x es fe. Con `data/agent-actuals.jsonl`
   es dato defendible.

Equipos con adopcion parcial: **2-5x** (honesto).
Equipos con adopcion total + scope favorable: **10x o mas** (defendible).

## Regime caveat

Regime "first draft + self-review + merge". Para mergeable PR aprobado por E1
humano, aplicar factor 0.5-0.7 al speedup. Legacy con constraints ocultas:
METR 2025-07 mide 0.84x regardless — asume 2x como tope honesto.

## Tracking empirico

Tras completar un spec, anadir una entrada JSONL a `data/agent-actuals.jsonl`
(gitignored, tracking local por PM):

```json
{"spec_id":"SE-XXX","category":"standard","human_estimate_days":5,"agent_estimate_hours_predicted":5.0,"agent_wallclock_hours_actual":1.25,"human_review_hours_actual":null,"rework_cycles":0,"verdict":"shipped","commit_sha":"abc123","completed_at":"2026-04-11T20:30:00Z"}
```

Valores de `verdict`: `shipped`, `shipped-with-fixes`, `abandoned`.

Template seed en `data/agent-actuals.example.jsonl` (tracked).

## Recalibracion

```
bash scripts/estimate-calibrate.sh            # banner humano
bash scripts/estimate-calibrate.sh --format json  # JSON parseable
```

El script agrupa por categoria, computa speedup empirico y sugiere ajustes
cuando la categoria tiene samples ≥ `DUAL_ESTIMATION_MIN_SAMPLES` (default 10).
Recalibrar mensualmente o cada 30 specs completados.

## Config keys

En `pm-config.md`:
```
DUAL_ESTIMATION_ENABLED     = true
DUAL_ESTIMATION_MIN_SAMPLES = 10
AGENT_ACTUALS_LOG           = "data/agent-actuals.jsonl"
```

## Sources

- METR arxiv 2503.14499 (time horizons, rev. 2026-02)
- METR arxiv 2507.09089 (2025-07 RCT, -19% en legacy repos)
- METR MirrorCode 2026-04-10 (greenfield, 10-50x)
- Experimento propio n=2 Apache HUDI (HUDI-8865 21x, HUDI-8551 30x ajustado)
- Datos internos pm-workspace: SE-001/002/008/012
