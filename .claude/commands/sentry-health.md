---
name: sentry-health
description: >
  Métricas de salud técnica del proyecto desde Sentry: errores, crash rate,
  performance, alertas activas. Alimenta sprint-status y kpi-dashboard.
---

# Salud Técnica — Sentry

**Argumentos:** $ARGUMENTS

> Uso: `/sentry-health --project {p}` o `/sentry-health --project {p} --period {días}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace. Busca `SENTRY_PROJECT` en su CLAUDE.md
- `--period {días}` — Período de análisis (por defecto: 14 = duración del sprint)
- `--env {entorno}` — Filtrar por entorno Sentry (production, staging, development)
- `--compare` — Comparar con el período anterior (útil para sprint review)

## Contexto requerido

1. `docs/rules/domain/connectors-config.md` — Verificar que Sentry está habilitado
2. `projects/{proyecto}/CLAUDE.md` — `SENTRY_PROJECT` y `SENTRY_ORG` si difiere del default

## Pasos de ejecución

1. **Verificar conector** — Comprobar que el conector Sentry está disponible
   - Si no está activado → mostrar instrucciones de activación

2. **Resolver proyecto Sentry**:
   - Si `--project` → buscar `SENTRY_PROJECT` en CLAUDE.md del proyecto
   - Si no encontrado → usar `SENTRY_DEFAULT_ORG` + pedir slug del proyecto
   - Organización: `SENTRY_DEFAULT_ORG` de connectors-config o la del proyecto

3. **Obtener métricas** usando el conector MCP de Sentry:
   - **Errores**: total de eventos, errores únicos, top 5 por frecuencia
   - **Crash Rate**: % de sesiones con crash (si aplica)
   - **Performance**: p50, p75, p95 de transacciones principales
   - **Alertas activas**: alertas no resueltas con severidad
   - **Releases**: últimas releases y su estabilidad

4. **Calcular indicadores de salud**:
   ```
   🟢 Saludable  — error rate < 1%, sin alertas críticas, p95 < objetivo
   🟡 Atención   — error rate 1-5% o alertas warning activas
   🔴 Crítico    — error rate > 5% o alertas critical activas
   ```

5. **Generar informe**:
   ```
   ## Salud Técnica — {proyecto} ({período})
   Estado: 🟢/🟡/🔴

   | Métrica | Valor | Tendencia |
   |---|---|---|
   | Errores únicos | N | ↑↓→ |
   | Error rate | N% | ↑↓→ |
   | P95 latencia | Nms | ↑↓→ |
   | Alertas activas | N (M críticas) | — |

   ### Top 5 errores por frecuencia
   1. [Error] descripción — N eventos — última vez: fecha
   ...

   ### Alertas activas
   - 🔴 {alerta}: descripción
   ...
   ```

6. Si `--compare` → añadir columna "Sprint anterior" y calcular deltas

## Integración con otros comandos

- `/sprint-status` puede invocar `sentry-health` para incluir métricas técnicas
- `/kpi-dashboard` usa los datos de salud como KPIs técnicos
- `/sprint-review` incluye tendencia de salud técnica en el resumen
- Soporta `--notify-slack` para publicar el informe en el canal del proyecto

## Restricciones

- **Solo lectura** — no modificar alertas ni configuración en Sentry
- Si Sentry no tiene datos del período → informar, no inventar métricas
- Respetar rate limits del conector
- No exponer tokens ni API keys en la salida
