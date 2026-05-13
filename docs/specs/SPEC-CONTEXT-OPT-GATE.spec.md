# Spec: Context Optimization Gate — Baseline + Re-measure for CLAUDE.md changes

**Task ID:**        SPEC-CONTEXT-OPT-GATE
**PBI padre:**      Context optimization discipline (research: Context vs Tokens report 2026-05)
**Sprint:**         2026-09
**Fecha creacion:** 2026-05-13
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     6h
**Estado:**         Pendiente
**Max turns:**      30
**Modelo:**         claude-sonnet-4-6

**Depends-on:**     SPEC-CACHE-HIT-TRACKING (must be implemented and have >=14d data before this spec can be enabled in enforcing mode)

---

## 0. Prerequisites (BLOCKING)

This spec CANNOT enter enforcing mode until:

1. SPEC-CACHE-HIT-TRACKING is implemented and `~/.savia/usage.db` exists with
   tables `turns`, `sessions`, `file_state`.
2. At least 14 days of cache_read / cache_creation telemetry has been collected
   across normal pm-workspace usage.
3. Aggregate cache hit rate baseline (workspace-wide) is computed and stored
   as `~/.savia/usage.db:aggregate_baseline`.

While prerequisites are not met, the gate runs in `dry-run` mode: it logs
intent but does not block writes. This is enforced by checking
`SELECT count(*) FROM turns WHERE ts > datetime('now','-14 days')` >= 1000
at hook startup.

---

## 1. Contexto y Objetivo

El informe "Context vs Tokens" (108 ejecuciones, 2026-05) reveló que:

- Baseline gana 2/3 tareas vs estrategias enriquecidas (Graphify, Plain ACM).
- Solo deepseek-v4-pro amortiza el coste de cargar Agent Code Map (CAC).
- Modificaciones a `CLAUDE.md` y `projects/*/CLAUDE.md` rompen el prompt cache
  con coste impredecible (cache_creation_input_tokens spike).

**Problema:** hoy cualquiera puede editar `CLAUDE.md` sin medir el impacto
real en cache hit rate. El criterio mecánico "<150 líneas" (Rule #11) NO
captura el problema real: **estabilidad del contenido + ratio static/dynamic**.

**Objetivo:** implementar un gate PreToolUse que, ante un Edit/Write sobre
ficheros `CLAUDE.md` o `projects/*/CLAUDE.md`:

1. Verifica si existe baseline en `context_baselines`.
2. Si no existe: pide ejecutar `/context-opt-baseline {file}` (no bloquea, warning).
3. Si existe pero la ventana de 14d aún no se cumplió: warning + permite.
4. Si existe y la ventana se cumplió: permite escritura, programa re-medición
   en D+7 y D+14, alerta si Δ_hit_rate < -10pp.

Esta spec NO sustituye Rule #11 (sigue siendo válida como heurística). Añade
una capa empírica encima.

**Criterios de Aceptacion:**

- [ ] AC-01: Existe tabla `context_baselines` en `~/.savia/usage.db` con schema
      definido en §3.
- [ ] AC-02: `/context-opt-baseline {file}` calcula baseline (14d hit rate del
      fichero) y lo persiste con `status='baseline_pending'` si <14d datos o
      `status='baseline_ready'` si ≥14d.
- [ ] AC-03: Hook PreToolUse `.opencode/hooks/context-opt-gate.sh` intercepta
      Edit|Write sobre `CLAUDE.md` y `projects/*/CLAUDE.md` (case-insensitive,
      normaliza path).
- [ ] AC-04: Hook respeta bypass `SAVIA_CONTEXT_OPT_BYPASS=1` (sale 0 sin
      logging).
- [ ] AC-05: Hook respeta dry-run si prerequisitos §0 no se cumplen.
- [ ] AC-06: Hook crea snapshot SHA256 del fichero antes de permitir
      escritura, en `~/.savia/context-opt-snapshots/{sha256}.md`.
- [ ] AC-07: `/context-opt-status` muestra tabla de baselines con columnas
      `file, baseline_started, days_elapsed, baseline_rate, current_rate, delta_pp, status`.
- [ ] AC-08: `/context-opt-revert {file}` restaura el snapshot anterior si
      Δ_d7 < -10pp.
- [ ] AC-09: Suite BATS `tests/test-context-opt-gate.bats` cubre los 8
      escenarios listados en §6 y obtiene score ≥80 en test-architect.

---

## 2. Reglas de Negocio (OPT-XX)

- **OPT-01:** El gate solo aplica a `CLAUDE.md` (raíz) y `projects/*/CLAUDE.md`.
  NO aplica a `_HUB.md`, agentes, skills, ni cualquier otro fichero.
- **OPT-02:** Si el fichero no existe aún (creación nueva), permite escritura
  y crea baseline inmediatamente con `status='baseline_pending'`.
- **OPT-03:** Ventana de baseline = 14 días naturales. Configurable vía
  `~/.savia/preferences.yaml:context_opt.baseline_window_days`.
- **OPT-04:** Umbral de alerta = -10pp en hit rate D+7 o D+14 vs baseline.
  Configurable vía `context_opt.alert_threshold_pp`.
- **OPT-05:** Snapshots se conservan 90 días, luego se purgan via cron diario
  `~/.savia/cron/context-opt-snapshot-purge.sh`.
- **OPT-06:** El hook es informativo (warning + log) si no hay baseline,
  NO bloquea. Solo bloquea si snapshot anterior tiene Δ < umbral Y el usuario
  intenta escribir sin haber ejecutado `/context-opt-revert` ni
  `/context-opt-baseline --force`.
- **OPT-07:** Bypass `SAVIA_CONTEXT_OPT_BYPASS=1` se loguea en
  `output/context-opt-audit.jsonl` con razón opcional `BYPASS_REASON=...`.
- **OPT-08:** El comando `/context-opt-baseline` requiere que
  SPEC-CACHE-HIT-TRACKING esté operativa. Si no, falla con error explícito.

---

## 3. Schema SQLite — `context_baselines`

```sql
CREATE TABLE IF NOT EXISTS context_baselines (
  file_path TEXT PRIMARY KEY,
  file_sha256 TEXT NOT NULL,
  baseline_started_at TEXT NOT NULL,
  baseline_window_days INTEGER NOT NULL DEFAULT 14,
  cache_hit_rate_baseline REAL,
  cache_hit_rate_d7 REAL,
  cache_hit_rate_d14 REAL,
  delta_d7_pp REAL,
  delta_d14_pp REAL,
  status TEXT NOT NULL CHECK (status IN ('baseline_pending','baseline_ready','measuring','alert','reverted')),
  snapshot_path TEXT,
  notes TEXT,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_context_baselines_status ON context_baselines(status);
```

---

## 4. Ficheros a crear / modificar

| Fichero | Acción | Notas |
|---|---|---|
| `scripts/context-opt-gate.py` | CREATE | Lógica del hook (Python por Rule #26) |
| `scripts/context-opt-measure.py` | CREATE | Re-mide D+7/D+14, alerta si Δ<-10pp |
| `.opencode/hooks/context-opt-gate.sh` | CREATE | Bash wrapper PreToolUse |
| `.opencode/commands/context-opt-baseline.md` | CREATE | Slash command |
| `.opencode/commands/context-opt-status.md` | CREATE | Slash command |
| `.opencode/commands/context-opt-revert.md` | CREATE | Slash command |
| `docs/rules/domain/context-opt-monitored.md` | CREATE | Lista de ficheros bajo monitorización |
| `docs/rules/domain/context-optimization-discipline.md` | CREATE | Regla canónica |
| `tests/test-context-opt-gate.bats` | CREATE | Suite BATS (≥80 score) |
| `.opencode/settings.json` | MODIFY | Registrar hook PreToolUse |

---

## 5. Hook PreToolUse — flujo

```
Input: tool_input.file_path, tool_input.content
1. Normalize path; case-insensitive match con OPT-01.
2. Si no coincide → exit 0.
3. Si SAVIA_CONTEXT_OPT_BYPASS=1 → log + exit 0.
4. Si prerequisitos §0 no cumplidos → log "dry-run" + exit 0.
5. SELECT * FROM context_baselines WHERE file_path = ?
6. Si NULL: warning "Sin baseline. Ejecuta /context-opt-baseline" + exit 0.
7. Si status='alert' y no hay snapshot reciente: DENY con razón.
8. Si OK: crear snapshot SHA256, actualizar updated_at, exit 0.
```

---

## 6. Test Scenarios (BATS)

1. Escritura de fichero fuera de OPT-01 → permitido sin log.
2. Bypass env var → permitido + log con razón.
3. Prerequisitos §0 no cumplidos → dry-run, no bloquea.
4. Fichero nuevo (CREATE) → baseline_pending + permite.
5. Baseline ready, sin alert → snapshot + permite.
6. Baseline en status='alert' sin revert → BLOCK.
7. `/context-opt-revert` restaura snapshot y limpia alert.
8. Cron purge elimina snapshots >90 días.

---

## 7. Dependencias y orden

1. SPEC-CACHE-HIT-TRACKING implementada y operando.
2. Esta spec implementada en dry-run.
3. Tras 14d de datos: enforcing.
4. Las specs SPEC-PROJECT-CONTEXT-DISCIPLINE y SPEC-HEAVY-CONTEXT-CRITERIA
   reusan tabla `context_baselines` y patrón de medición.

---

## 8. Riesgos

- **R1:** Hook añade latencia a Edit/Write sobre CLAUDE.md. Mitigación: query
  SQLite indexado, target <50ms.
- **R2:** Falsos positivos si cache_hit_rate baja por causas externas
  (cambios upstream Anthropic). Mitigación: comparar con
  `aggregate_baseline` workspace-wide; si baja en paralelo, NO alertar.
- **R3:** Snapshots ocupan espacio. Mitigación: purga 90d + warning si
  `~/.savia/context-opt-snapshots/` > 100MB.
