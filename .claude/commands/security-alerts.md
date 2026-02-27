---
name: security-alerts
description: >
  Alertas de seguridad desde Azure DevOps Advanced Security.
  CVEs, dependencias vulnerables, secrets expuestos.
---

# Security Alerts

**Argumentos:** $ARGUMENTS

> Uso: `/security:alerts --project {p}` o `/security:alerts --project {p} --severity {level}`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--repo {nombre}` — Repositorio específico (defecto: todos)
- `--severity {critical|high|medium|low}` — Filtrar por severidad
- `--type {dependency|secret|code}` — Filtrar por tipo de alerta
- `--status {active|dismissed|fixed}` — Filtrar por estado
- `--create-pbi` — Crear PBIs para alertas críticas/high

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. Azure DevOps Advanced Security habilitado en el proyecto

## Pasos de ejecución

### 1. Obtener alertas
- MCP: `get_alerts` → listar alertas de seguridad del proyecto
- Filtrar por parámetros proporcionados
- Para cada alerta: MCP: `get_alert_details` → detalle completo

### 2. Clasificar y priorizar

| Tipo | Descripción | Severidad típica |
|---|---|---|
| Dependency | CVE en dependencia (NuGet, npm, pip...) | Variable |
| Secret | Token, key, password en código | Critical |
| Code | Vulnerability pattern en código fuente | Variable |

Priorización: Critical → High → Medium → Low × edad de la alerta

### 3. Presentar dashboard

```
## Security Alerts — {proyecto}
Fecha: YYYY-MM-DD | Repos analizados: 3

### Resumen
| Severidad | Activas | Dismissed | Fixed |
|---|---|---|---|
| 🔴 Critical | 2 | 0 | 3 |
| 🟠 High | 5 | 1 | 8 |
| 🟡 Medium | 12 | 3 | 15 |
| ⚪ Low | 8 | 5 | 20 |

### Alertas críticas activas
| # | Tipo | Descripción | Repo | Edad |
|---|---|---|---|---|
| 1 | Secret | GitHub token en appsettings.json | backend | 5 días |
| 2 | Dependency | CVE-2026-1234 en auth-lib v2.1 (RCE) | backend | 12 días |

### Alertas high activas
| # | Tipo | Descripción | Repo | Edad |
|---|---|---|---|---|
| 1 | Dependency | CVE-2026-5678 en lodash v4.17 (XSS) | frontend | 3 días |
| 2 | Code | SQL injection pattern en UserController | backend | 8 días |
...

### Recomendaciones
1. 🚨 Rotar GitHub token expuesto INMEDIATAMENTE
2. Actualizar auth-lib v2.1 → v3.0 (fix CVE-2026-1234)
3. Actualizar lodash v4.17 → v4.18 (fix CVE-2026-5678)

### Tendencia (últimos 30 días)
Nuevas: 8 | Resueltas: 11 | Netas: -3 (mejorando 📉)
```

### 4. Crear PBIs (si `--create-pbi`)
- Para cada alerta Critical/High activa → proponer PBI tipo Bug
- **Confirmar con PM** antes de crear
- Incluir: CVE ID, severidad, fix recomendado, repo afectado

## Integración

- `/project:audit` → incluye security alerts en evaluación
- `/evaluate:repo` → complementario (evaluate:repo = estático, security:alerts = dinámico)
- `/debt:track` → alertas no resueltas como deuda de seguridad
- `/risk:log` → alertas critical alimentan registro de riesgos

## Restricciones

- Requiere Azure DevOps Advanced Security habilitado
- MCP tools: `get_alerts`, `get_alert_details`
- No remedia automáticamente — solo reporta y propone PBIs
- Crear PBIs requiere confirmación del PM
