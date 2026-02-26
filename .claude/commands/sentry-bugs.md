---
name: sentry-bugs
description: >
  Crear PBIs en Azure DevOps a partir de errores frecuentes en Sentry.
  Analiza issues, agrupa por causa raíz y propone work items.
---

# Bugs desde Sentry → PBIs

**Argumentos:** $ARGUMENTS

> Uso: `/sentry:bugs --project {p}` o `/sentry:bugs --project {p} --min-events {N}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace
- `--min-events {N}` — Umbral mínimo de eventos para considerar un issue (defecto: 10)
- `--period {días}` — Período de análisis (defecto: 14)
- `--env {entorno}` — Filtrar por entorno (defecto: production)
- `--dry-run` — Solo mostrar propuesta, no crear nada
- `--auto-assign` — Asignar automáticamente según equipo.md y área afectada

## Contexto requerido

1. `.claude/rules/connectors-config.md` — Verificar Sentry habilitado
2. `projects/{proyecto}/CLAUDE.md` — `SENTRY_PROJECT`, `AZURE_DEVOPS_PROJECT`
3. `projects/{proyecto}/equipo.md` — Para auto-asignación (opcional)

## Pasos de ejecución

1. **Verificar conector** — Comprobar Sentry disponible
   - Si no activado → mostrar instrucciones

2. **Obtener issues de Sentry**:
   - Filtrar por: período, entorno, `is:unresolved`, eventos >= min-events
   - Ordenar por frecuencia descendente
   - Obtener: título, culprit, stack trace resumido, primera/última vez, usuarios afectados

3. **Analizar y agrupar**:
   - Agrupar issues por causa raíz (mismo módulo/fichero/servicio)
   - Detectar issues ya vinculados a PBIs existentes (buscar `[Sentry#ID]` en DevOps)
   - Excluir issues ya resueltos o ignorados en Sentry

4. **Generar propuesta de PBIs**:
   ```
   ## Bugs desde Sentry — {proyecto} ({período})

   Se encontraron N issues con >= {min} eventos.
   Ya vinculados a PBIs: M | Nuevos: K

   | # | Sentry Issue | Eventos | Usuarios | Módulo | PBI propuesto |
   |---|---|---|---|---|---|
   | 1 | PROJ-ABC | 523 | 89 | api/auth | Fix: fallo autenticación OAuth... |
   | 2 | PROJ-DEF | 201 | 45 | web/cart | Fix: error al calcular descuento... |
   ...

   ### Detalle por PBI propuesto

   #### 1. Fix: fallo autenticación OAuth al renovar token
   - **Sentry issues**: PROJ-ABC, PROJ-GHI (misma causa raíz)
   - **Impacto**: 612 eventos, 89 usuarios, primera vez: 2026-02-15
   - **Stack trace**: `auth/oauth.py:142 → refresh_token() → TokenExpiredError`
   - **Severidad propuesta**: 2 (Alta) — afecta autenticación
   - **Estimación**: 8h
   ```

5. **Confirmar con el PM** — Presentar tabla y pedir confirmación
   - ⚠️ **NUNCA crear PBIs sin confirmación explícita** (Regla 7)
   - Permitir editar títulos, severidad, estimación antes de crear

6. Si confirmado → **Crear PBIs en Azure DevOps**:
   - Tipo: Bug
   - Título: `[Sentry#ID] Descripción del fix`
   - Description: stack trace + impacto + link a Sentry
   - Tags: `sentry`, `bug`, `{módulo}`
   - Severity: según impacto (usuarios afectados × frecuencia)
   - Link: URL del issue en Sentry

7. **Confirmar creación**:
   ```
   ✅ Creados N PBIs (Bug) en Azure DevOps:
   - AB#1234: [Sentry#ABC] Fix: fallo autenticación OAuth...
   - AB#1235: [Sentry#DEF] Fix: error al calcular descuento...
   ```

## Integración con otros comandos

- `/pbi:decompose` puede descomponer los bugs creados en tasks técnicas
- `/sprint:plan` puede incluir bugs de Sentry como candidatos al sprint
- `/notify:slack` puede publicar resumen de bugs detectados
- `/sentry:health` complementa con visión general de salud

## Restricciones

- **NUNCA crear PBIs sin confirmación** del PM (Regla 7)
- No duplicar: verificar siempre si ya existe PBI vinculado al Sentry issue
- No modificar issues en Sentry (solo lectura desde Sentry)
- Máximo 20 PBIs por ejecución (protección contra spam)
- Si `--dry-run` → solo mostrar propuesta, no escribir en DevOps
