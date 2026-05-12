---
name: obs-dashboard
description: Dashboard de observabilidad digesto por rol — CEO, CTO, PM, Dev, QA, SRE
developer_type: all
agent: task
context_cost: high
---

# /obs-dashboard

> 🦉 Dashboard personalizado de observabilidad. Cada rol ve lo que importa.

---

## Sintaxis

```
/obs-dashboard [--role ceo|cto|pm|dev|qa|sre] [--project nombre] [--period 24h|7d|30d] [--lang es|en]
```

---

## Flujo

### Paso 1 — Detectar rol

Usar `--role` o leer de `identity.md` del perfil activo. Default fallback: `dev`.

### Paso 2 — Consultar fuentes conectadas

Leer `.claude/profiles/integrations/obs-*.md` (Grafana, Datadog, App Insights, OpenTelemetry).
Ejecutar queries de salud en paralelo. Consolidar resultados normalizados.

### Paso 3 — Dashboard por rol

**CEO/CTO**: availability %, SLA, incidentes abiertos, cost trend, alertas críticas
**PM**: usuarios afectados, impacto features, deploy correlations, decisiones recomendadas
**Dev/SRE**: latencia por servicio, error rates, logs/traces con errores, recursos
**QA**: pre/post deploy comparison, regresiones, error vs baseline, criterios pass/fail

Ejemplo: `/obs-dashboard --role pm` muestra qué usuarios impactó el último deploy.

### Paso 4 — Correlacionar con eventos

- Buscar deployments recientes en git/CI-CD
- Correlacionar cambios de métricas con timestamps de deployments
- Marcar anomalías y sus correlaciones

### Paso 5 — Guardar y resumir

Guardar completo en `output/dashboards/YYYYMMDD-{role}-dashboard.md`.
Mostrar resumen (15–20 líneas) + ruta del archivo + próximos pasos.

---

## Opciones

- `--verbose` → detalles técnicos completos
- `--period 7d --compare` → comparar con semana anterior
- `--project {nombre}` → filtrar a un proyecto (múltiple si omitido)

---

## Integración

- `/obs-status` → health check rápido de fuentes
- `/obs-query` → preguntar sobre métrica específica
- `/obs-connect` → conectar nueva fuente si falta

