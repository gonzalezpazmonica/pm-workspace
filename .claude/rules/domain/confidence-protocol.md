---
globs: ["data/confidence-log.jsonl"]
---

# Regla: Confidence Calibration Protocol
# ── Logging de resoluciones NL, decay por fallos, recalibración periódica ────

> Complemento de `nl-command-resolution.md`. Define cómo registrar cada resolución,
> aplicar decay en patrones fallidos, y ejecutar recalibración periódica.

---

## Logging Obligatorio

**Cuándo:** Después de ejecutar cada resolución NL (paso 7 en nl-command-resolution.md).

**Formato JSONL:** Cada línea es un JSON:
```json
{
  "command": "crear issue en backlog",
  "confidence": 82,
  "success": true,
  "timestamp": "2026-03-04T09:15:00Z",
  "pattern": "crear.*issue",
  "band": "high"
}
```

**Campos obligatorios:**
- `command` (string): comando resolto
- `confidence` (int): 0-100, score final que se usó
- `success` (boolean): ¿se ejecutó correctamente?
- `timestamp` (ISO 8601 UTC)
- `pattern` (string): patrón regex usado para mapear
- `band` (string): high|mid|low (≥80% / 60-79% / <60%)

**Fichero:** `data/confidence-log.jsonl` (append-only)

---

## Decay Mechanism

### Patrón: últimos 3 fallos consecutivos

Si las últimas 3 resoluciones del MISMO `pattern` fueron fallidas:
- Reducir base confidence de ese patrón en 5%
- Log de decay en comentario
- Minimum floor: 30% (nunca bajar más)

**Ejemplo:**
```
Patrón "crear.*pbi" con base 85%:
  - Intento 1: fallo
  - Intento 2: fallo
  - Intento 3: fallo → decay: 85% - 5% = 80%
```

### Comando: últimos 5 fallos consecutivos

Si las últimas 5 resoluciones del MISMO `command` fueron fallidas:
- Reducir base confidence en 10%
- Minimum floor: 30%

---

## Recovery Mechanism

Después de decay, si se logran 3 ejecuciones correctas consecutivas:
- Recuperar 3% de confianza por ejecución (máx +9% por patrón)
- No recuperar más allá de la línea base original pre-decay

**Cronograma:**
```
Patrón decayado (80%): intento 4 éxito → 83%, intento 5 éxito → 86%, etc.
```

---

## Recalibración Periódica

**Trigger:** Mensualmente (o después de 50 nuevas entradas en el log)

**Comando:** `bash scripts/confidence-calibrate.sh report`

**Output:**
- Tabla de accuracy por band
- Brier score general
- Recomendaciones de ajuste si Brier > 0.2

**Acciones por recomendación:**
- Si accuracy band <60% es <70% → aumentar penalización base en 10%
- Si accuracy band 60-79% es <75% → ajustar bonus historial ±2%
- Si accuracy band ≥80% es <85% → reducir base en 10%

---

## Anti-Patterns (Prohibido)

1. **NUNCA** ajustar confianza sin registrar en el log
2. **NUNCA** saltarse decay en comandos destructivos (delete, drop, reset)
   - Estos SIEMPRE requieren confirmación explícita, sin excepciones
3. **NUNCA** recalibrar sin ejecutar `confidence-calibrate.sh` primero
4. **NUNCA** guardar el log en Git — es fichero local de datos
   - Incluir `data/confidence-log.jsonl` en `.gitignore`

---

## Integración

Este protocolo se integra con:
- **nl-command-resolution.md** — paso 8.5 es registrar en confidence-log.jsonl
- **confidence-calibrate.sh** — analiza el log, sugiere ajustes
- **pm-config.md** — puede incluir `CONFIDENCE_DECAY_PERCENT`, `CONFIDENCE_FLOOR`
- **Hooks** — pre-commit puede sugerir `/confidence-calibrate.sh summary` si hay cambios

---

## Formato de Actualización Manual

Si se necesita ajustar manualmente los parámetros de base:

```yaml
# En CLAUDE.md del proyecto o pm-config.md
CONFIDENCE_BASE_RANGES:
  low: [50, 70]      # min, max para rango <60%
  mid: [70, 80]      # rango 60-79%
  high: [80, 95]     # rango ≥80%
CONFIDENCE_DECAY_PERCENT: 5        # puntos por 3 fallos
CONFIDENCE_DECAY_HARD: 10           # puntos por 5 fallos
CONFIDENCE_FLOOR: 30                # mínimo absoluto
CONFIDENCE_RECOVERY_PER_SUCCESS: 3  # puntos por success tras decay
```

