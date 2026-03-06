---
title: "Previsión de Capacidad Telecomunicaciones"
description: "Medición, previsión y planificación de capacidad de red con alertas automáticas"
icon: "📊"
category: "Telecomunicaciones"
---

# Previsión de Capacidad Telecomunicaciones

Administra la medición de capacidad actual, previsión de necesidades futuras, planificación de expansión con análisis de costes y alertas automáticas de acercamiento a límites.

## Subcomandos

### measure
Registra la utilización actual de capacidad por segmento de red.

**Uso:** `capacity-forecast-telco measure [opciones]`

**Parámetros:**
- `--segmento` - Segmento de red (backbone, acceso, core, borde) (requerido)
- `--utilizacion` - Porcentaje de utilización (0-100) (requerido)
- `--capacidad-total` - Capacidad total en Gbps (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
capacity-forecast-telco measure \
  --segmento "backbone" \
  --utilizacion "65" \
  --capacidad-total "500" \
  --proyecto mi-telco
```

**Resultado:** Crea registro en `projects/{proyecto}/telco/capacity/measurements.yaml` con timestamp de medición.

### forecast
Proyecta necesidades futuras de capacidad basadas en tendencias y crecimiento de suscriptores.

**Uso:** `capacity-forecast-telco forecast [opciones]`

**Parámetros:**
- `--segmento` - Segmento de red (requerido)
- `--periodos` - Número de meses a proyectar (requerido)
- `--tasa-crecimiento` - Tasa de crecimiento esperada % (opcional)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
capacity-forecast-telco forecast \
  --segmento "acceso" \
  --periodos "12" \
  --tasa-crecimiento "15" \
  --proyecto mi-telco
```

**Resultado:** Proyección mes a mes con estimación de cuándo se alcanzará 80% de utilización.

### plan
Crea un plan de expansión de capacidad con costes y timeline.

**Uso:** `capacity-forecast-telco plan [opciones]`

**Parámetros:**
- `--segmento` - Segmento a expandir (requerido)
- `--capacidad-adicional` - Capacidad a añadir en Gbps (requerido)
- `--timeline` - Plazo de implementación en meses (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
capacity-forecast-telco plan \
  --segmento "backbone" \
  --capacidad-adicional "200" \
  --timeline "6" \
  --proyecto mi-telco
```

**Resultado:** Plan guardado en `projects/{proyecto}/telco/capacity/plans/PLAN-NNNN.yaml` con:
- Desglose de costes (equipamiento, instalación, personal)
- Cronograma de implementación
- Riesgos identificados
- Alternativas evaluadas

### alert
Muestra segmentos que se aproximan a los límites de capacidad.

**Uso:** `capacity-forecast-telco alert [opciones]`

**Parámetros:**
- `--umbral` - Umbral de alerta: 70, 80, 90 (opcional, default: 80)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
capacity-forecast-telco alert \
  --umbral "80" \
  --proyecto mi-telco
```

**Resultado:** Lista segmentos en riesgo:
```
🔴 CRÍTICO (>90%): core — 92% utilización — ACCIÓN INMEDIATA
🟡 ALTO (80-90%): acceso — 85% utilización — planificar expansión Q2
🟢 NORMAL (<80%): borde — 45% utilización
```

## Almacenamiento

Todos los datos se guardan en `projects/{proyecto}/telco/capacity/` con estructura YAML:
- `measurements.yaml` — Mediciones históricas
- `forecasts.yaml` — Proyecciones calculadas
- `plans/` — Planes de expansión

