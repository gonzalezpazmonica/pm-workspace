---
name: context-optimize
description: Analizar patrones de uso de contexto y sugerir optimizaciones al context-map
developer_type: all
agent: none
context_cost: medium
---

# /context-optimize

> 🦉 Savia analiza cómo usas el contexto y sugiere cómo mejorarlo.

---

## Cargar perfil de usuario

Grupo: **Memory & Context** — cargar:

- `identity.md` — slug (para aislar datos por usuario)

Ver `.claude/profiles/context-map.md`.

---

## Flujo

### Paso 1 — Leer log de uso de contexto

1. Verificar que existe `$HOME/.pm-workspace/context-usage.log`
2. Si no existe → informar que el tracking no está activo
3. Si existe → parsear entradas (formato: `timestamp|comando|fragmentos|tokens_est`)

### Paso 2 — Analizar patrones

1. **Fragmentos más cargados**: Ranking de ficheros por frecuencia de carga
2. **Fragmentos menos cargados**: Ficheros que se cargan pero raramente se usan
3. **Co-ocurrencias**: Pares de comandos que se ejecutan juntos frecuentemente
4. **Cargas innecesarias**: Fragmentos cargados por el context-map pero que no aparecen en outputs
5. **Cargas faltantes**: Comandos seguidos de recarga inmediata (señal de contexto insuficiente)

### Paso 3 — Generar recomendaciones

Para cada hallazgo, generar recomendación con nivel de confianza:

- **Alta confianza (>20 ocurrencias)**: Sugerir cambio en context-map
- **Media confianza (10-20)**: Sugerir revisión por el usuario
- **Baja confianza (<10)**: Solo informar, no recomendar cambio

Tipos de recomendación:

1. **Degradar**: Mover fragmento de carga obligatoria a opcional
2. **Promover**: Mover fragmento de NO-cargar a cargar
3. **Agrupar**: Fusionar grupos del context-map que siempre se usan juntos
4. **Separar**: Dividir un grupo que carga fragmentos con uso desigual
5. **Pre-mapear**: Añadir comandos al context-map que siempre se ejecutan en secuencia

### Paso 4 — Mostrar informe

Banner: `🦉 Context Optimization — análisis de {N} sesiones`

```
📊 Resumen de uso

Sesiones analizadas: {N}
Período: {fecha_inicio} — {fecha_fin}
Tokens estimados consumidos: {total}
Tokens estimados ahorrables: {ahorro} ({porcentaje}%)

🔍 Hallazgos

{lista de hallazgos con nivel de confianza}

💡 Recomendaciones

{lista de recomendaciones priorizadas}
```

### Paso 5 — Aplicar (opcional)

Si el usuario acepta una recomendación:

1. Generar diff del context-map propuesto
2. Mostrar antes/después
3. Pedir confirmación
4. Aplicar cambio
5. Resetear log para medir el impacto

---

## Subcomandos

- `/context-optimize` — análisis completo con recomendaciones
- `/context-optimize stats` — solo estadísticas, sin recomendaciones
- `/context-optimize reset` — limpiar log para empezar medición fresca
- `/context-optimize apply {id}` — aplicar recomendación específica

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: context_optimize
sessions_analyzed: 47
period: "2026-02-01/2026-03-01"
tokens_total: 284000
tokens_saveable: 42600
savings_percent: 15
recommendations:
  - id: 1
    type: degrade
    target: "tone.md en grupo Sprint & Daily"
    confidence: high
    savings_est: 12000
  - id: 2
    type: pre_map
    target: "sprint-status + report-hours"
    confidence: medium
    savings_est: 8500
```

---

## Restricciones

- **NUNCA** modificar el context-map sin confirmación explícita
- **NUNCA** eliminar datos del log sin confirmación
- El log solo contiene metadata (comando + fragmentos), NUNCA contenido de usuario
- Las recomendaciones son sugerencias — el usuario decide
