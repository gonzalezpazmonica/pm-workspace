# Spec: Autocompact Calibration — Recalibrar zonas de contexto a 75%

**Task ID:**        SPEC-AUTOCOMPACT-CALIBRATION
**PBI padre:**      Dev-session quality improvement (research: claude-code-from-source)
**Sprint:**         2026-15
**Fecha creacion:** 2026-04-10
**Creado por:**     Savia (research: claude-code-from-source)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     3h
**Estado:**         Pendiente
**Prioridad:**      ALTA
**Max turns:**      20
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

El research en `claude-code-from-source` confirma que la degradacion del
context window NO es un acantilado sino una curva gradual (TurboQuant,
arXiv:2504.19874). La calidad se mantiene >95% hasta el 85% de uso, y
solo cae significativamente por encima del 90%.

Actualmente `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65` en `.claude/settings.json`
dispara autocompact demasiado pronto (~108K tokens sobre effective 167K),
cortando sesiones productivas a mitad de trabajo. Las zonas definidas en
`context-health.md` (Verde <50%, Gradual 50-65%, Alerta 65-85%, Critica
>85%) estan mal calibradas respecto a los datos reales del modelo.

**Objetivo:** Subir `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` de 65 a 75 y
recalibrar las zonas en `context-health.md` segun datos reales:
Verde <50%, Gradual 50-70%, Alerta 70-85%, Critica >85%. Crear
`scripts/context-calibration-measure.sh` para medir calidad real por
zona y validar la recalibracion empiricamente.

**Criterios de Aceptacion:**
- [ ] AC-01: `.claude/settings.json` tiene `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75`
- [ ] AC-02: `context-health.md` documenta nuevas zonas (50/70/85)
- [ ] AC-03: `scripts/context-calibration-measure.sh` mide calidad por zona
- [ ] AC-04: Script genera informe JSON con Brier score por zona
- [ ] AC-05: Tests BATS cubren happy path y edge cases de calibracion
- [ ] AC-06: `CHANGELOG.md` documenta el cambio con justificacion

---

## 2. Contrato Tecnico

### 2.1 Requisitos funcionales

| ID | Requisito | Medible |
|----|-----------|---------|
| REQ-01 | Settings tiene CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75 | grep en .claude/settings.json |
| REQ-02 | context-health.md define 4 zonas con umbrales 50/70/85 | Seccion "Zonas de contexto" actualizada |
| REQ-03 | Script measure.sh acepta --zone {verde|gradual|alerta|critica} | CLI |
| REQ-04 | Script mide Brier score agregado en N sesiones | Output JSON con brier_by_zone |
| REQ-05 | Script detecta si una zona tiene Brier > 0.2 (calidad degradada) | Flag `needs_recalibration` |
| REQ-06 | Recomendacion automatica si Brier > 0.2 | Sugerencia de nuevos umbrales |
| REQ-07 | Script lee de `data/context-usage.log` (ya existe) | Reutiliza datos |
| REQ-08 | Output: `output/context-calibration-{fecha}.json` | Estructurado |

### 2.2 Interfaz / Firma

```bash
# scripts/context-calibration-measure.sh
# Usage: bash scripts/context-calibration-measure.sh [options]
#
# Options:
#   --log FILE      Log de uso. Default: data/context-usage.log
#   --zone Z        Solo medir una zona (verde|gradual|alerta|critica)
#   --min-samples N Minimo de muestras para medir. Default: 10
#   --output FILE   Output JSON. Default: output/context-calibration-{fecha}.json
#   --json          Solo output JSON, sin texto en stdout
#
# Exit: 0 ok, 1 error config, 2 datos insuficientes
```

### 2.3 Formato de output JSON

```json
{
  "timestamp": "2026-04-10T14:30:00Z",
  "settings": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": 75,
    "effective_window_tokens": 167000
  },
  "zones": {
    "verde": {"range": [0, 50], "samples": 45, "brier": 0.08, "quality": "optimal"},
    "gradual": {"range": [50, 70], "samples": 32, "brier": 0.11, "quality": "good"},
    "alerta": {"range": [70, 85], "samples": 18, "brier": 0.18, "quality": "acceptable"},
    "critica": {"range": [85, 100], "samples": 5, "brier": 0.35, "quality": "degraded"}
  },
  "needs_recalibration": false,
  "recommendations": []
}
```

### 2.4 Zonas calibradas (nueva definicion)

| Zona | Rango | Accion | Calidad esperada |
|------|-------|--------|------------------|
| Verde | <50% | Sin accion | >99% |
| Gradual | 50-70% | Sugerir /compact, no bloquear | >97% |
| Alerta | 70-85% | Bloquear operaciones pesadas | 92-97% |
| Critica | >85% | Bloquear todo, forzar compact | <92% |

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| AC-01 | Umbrales deben ser crecientes: 50 < 70 < 85 < 100 | Error: umbrales invalidos |
| AC-02 | CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = umbral de Gradual/Alerta = 70 o 75 | Warning si difiere |
| AC-03 | Minimo 10 muestras por zona para calcular Brier valido | Datos insuficientes |
| AC-04 | Brier > 0.2 en cualquier zona -> needs_recalibration=true | Recomendar ajuste |
| AC-05 | Log de uso se lee append-only, nunca modificar | Integridad |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Performance | <2s para medir con 1000 muestras |
| Dependencias | jq, bash 4.0+, awk |
| Compatibilidad | Linux + macOS |
| Datos | Reutilizar data/context-usage.log existente |
| Retrocompatibilidad | No romper comandos que leen context-health.md |

---

## 5. Test Scenarios

### T1 — Happy path: cambio de settings aplicado

```
GIVEN   .claude/settings.json con CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65
WHEN    se aplica el cambio manual a 75
THEN    grep "75" .claude/settings.json devuelve match
AND     context-health.md muestra "50-70%" como zona Gradual
AND     CHANGELOG.md tiene entrada con justificacion
```

### T2 — Medicion con datos suficientes

```
GIVEN   data/context-usage.log con >=10 muestras por zona
WHEN    bash scripts/context-calibration-measure.sh
THEN    exit code 0
AND     output/context-calibration-{fecha}.json existe
AND     cada zona tiene samples >= 10
AND     brier se calcula para cada zona
```

### T3 — Datos insuficientes

```
GIVEN   data/context-usage.log con <10 muestras totales
WHEN    bash scripts/context-calibration-measure.sh
THEN    exit code 2
AND     stderr contiene "insufficient samples"
AND     no se genera output JSON
```

### T4 — Recalibracion necesaria detectada

```
GIVEN   log con zona "gradual" con Brier = 0.25
WHEN    bash scripts/context-calibration-measure.sh
THEN    JSON tiene needs_recalibration=true
AND     recommendations incluye sugerencia de bajar umbral gradual
AND     exit code 0 (informativo, no error)
```

### T5 — Filtro por zona

```
GIVEN   log completo con 4 zonas
WHEN    bash scripts/context-calibration-measure.sh --zone alerta
THEN    output JSON solo contiene la zona "alerta"
AND     otras zonas no aparecen en el informe
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Modificar | .claude/settings.json | CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: 65 -> 75 |
| Modificar | docs/rules/domain/context-health.md | Zonas: 50/65/85 -> 50/70/85 |
| Crear | scripts/context-calibration-measure.sh | Script de medicion |
| Crear | tests/test-context-calibration.bats | Suite BATS (T1-T5) |
| Modificar | CHANGELOG.md | Entrada con justificacion del cambio |
| Modificar | docs/best-practices-claude-code.md | Actualizar menciones a 65% por 75% |

---

## 7. Referencias

- TurboQuant paper: arXiv:2504.19874 (context window quality gradual)
- Research: claude-code-from-source (autocompact mechanism analysis)
- Anthropic docs: effective_window = contextWindow - 20K (output) - 13K (buffer)
- Regla actual: docs/rules/domain/context-health.md seccion 3

---

## 8. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Sesiones productivas antes de compact | +15% duracion media | Comparar antes/despues en 20 sesiones |
| Autocompacts prematuros | -50% (zona gradual no dispara) | Contar en logs |
| Brier score zona alerta | <0.20 | Script measure.sh |
| Tests BATS | 5/5 passing | tests/run-all.sh |

---

## Checklist Pre-Entrega

- [ ] .claude/settings.json actualizado y validado con jq
- [ ] context-health.md zonas recalibradas (50/70/85)
- [ ] scripts/context-calibration-measure.sh pasa shellcheck
- [ ] Tests BATS pasan 5/5
- [ ] CHANGELOG.md documenta el cambio con enlace a research
- [ ] Medicion baseline guardada en output/ para comparar post-cambio
- [ ] best-practices-claude-code.md actualizado (valor 65 -> 75)
