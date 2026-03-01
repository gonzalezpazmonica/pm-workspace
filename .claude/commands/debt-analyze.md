---
name: debt-analyze
description: >
  Análisis automático de deuda técnica — hotspots, code smells, coupling temporal.
  Detecta complejidad, cambios acoplados, olores de código, frecuencia de cambio,
  antigüedad de código. Integración opcional con SonarQube.
developer_type: agent-single
agent: architect
context_cost: high
---

# Debt Analyze

**Argumentos:** $ARGUMENTS

> Uso: `/debt-analyze --project {p}` o `/debt-analyze --project {p} --days 30`

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Architecture & Debt** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar profundidad del análisis según `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 /debt-analyze — Análisis automático de deuda
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 3. Parámetros

- `--project {nombre}` — Proyecto (obligatorio)
- `--days {N}` — Ventana temporal: 30 (default), 60, 90
- `--sonarqube {url}` — URL SonarQube (si está disponible)

## 4. Análisis a ejecutar

1. **Complexity Hotspots**: Detectar ficheros con mayor complejidad ciclomática
   - Heurística: líneas × frecuencia de cambio en últimos 30 días
   - Marcar ficheros > 200 líneas sin refactorizar ≥ 6 meses

2. **Change Coupling**: Ficheros que cambian juntos (git log últimos N días)
   - Indicador de acoplamiento temporal → refactorizar juntos

3. **Code Smells por fichero**: Long files (> 150 líneas), anidamiento profundo
   - Detectar funciones > 30 líneas, métodos > 5 parámetros

4. **Churn Analysis**: Ficheros más modificados en últimos N días
   - Priorizar los de mayor volatilidad

5. **Age Analysis**: Ficheros sin cambios significativos ≥ 6 meses
   - Candidatos para refactorizar (riesgo > tiempo ocioso)

6. **SonarQube Enrichment** (si `SONARQUBE_URL` + `SONARQUBE_TOKEN` disponibles):
   - Integrar bugs, vulnerabilities, code smells de SonarQube
   - Combinar con análisis local

## 4. Formato de salida

```
## Análisis de Deuda Técnica — {proyecto} — {fecha}

### Hotspots de Complejidad (Top 5)
| Fichero | Complejidad | Líneas | Últimos cambios | Severidad |
|---|---|---|---|---|
| src/AuthController.cs | 24 | 287 | 8 cambios/30d | Critical |
| src/PaymentService.cs | 18 | 165 | 5 cambios/30d | High |

### Change Coupling (archivos que siempre van juntos)
- src/User.cs ↔ src/UserValidator.cs — 12 commits conjuntos
- src/Order.cs ↔ src/OrderService.cs — 8 commits conjuntos

### Code Smells
| Fichero | Tipo | Detalles | Esfuerzo |
|---|---|---|---|
| Models/Legacy.cs | Large file | 412 líneas | 8h |
| Handlers/Process.cs | Deep nesting | 6 niveles if | 4h |

### Churn (últimos 30 días)
- src/AuthController.cs — 18 commits (↑↑↑ Inestable)
- src/Startup.cs — 12 commits (↑↑ Problemas recurrentes)

### Age Analysis (sin cambios ≥ 6 meses)
- src/Deprecated/OldReporting.cs — último cambio: hace 8 meses

Deuda Total Estimada: **127 horas** (Critical: 32h, High: 58h, Medium: 37h)
```

## 5. Salida de fichero

- Guardar en: `projects/{proyecto}/debt/analysis-{YYYYMMDD}.md`
- Nombre uniforme para tracking histórico

## 6. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /debt-analyze — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Análisis guardado: projects/{proyecto}/debt/analysis-{fecha}.md
⏱️  Duración: ~1-2 min
→ Siguiente: /debt-prioritize --project {proyecto}
```
