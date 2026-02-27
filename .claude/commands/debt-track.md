---
name: debt-track
description: >
  Registro y seguimiento de deuda técnica por proyecto.
  Ratio de deuda, tendencia por sprint, integración con SonarQube.
---

# Debt Track

**Argumentos:** $ARGUMENTS

> Uso: `/debt:track --project {p}` o `/debt:track --project {p} --add`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--add` — Registrar nuevo item de deuda técnica
- `--resolve {id}` — Marcar item como resuelto
- `--sprint-report` — Informe de deuda del sprint actual
- `--sonarqube {url}` — Importar métricas desde SonarQube (opcional)
- `--severity {critical|high|medium|low}` — Filtrar por severidad

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `projects/{proyecto}/debt-register.md` — Registro de deuda (se crea si no existe)

## Pasos de ejecución

### Modo vista (por defecto)
1. **Leer registro** — `projects/{proyecto}/debt-register.md`
2. **Calcular métricas:**
   - Total items abiertos por severidad
   - Debt ratio: items deuda / total PBIs del sprint
   - Tendencia: comparar con últimos 5 sprints
   - Edad media de items sin resolver
3. **Si `--sonarqube`** → importar code smells, bugs, vulnerabilities
4. **Presentar dashboard:**

```
## Deuda Técnica — {proyecto} — Sprint {n}

Debt Ratio: 18% (objetivo < 20%) 🟢
Items abiertos: 12 | Resueltos este sprint: 3 | Nuevos: 2
Tendencia: 📉 mejorando (-2 vs sprint anterior)

| ID | Severidad | Descripción | Edad | Asignado |
|---|---|---|---|---|
| DT-01 | critical | SQL injection en AuthController | 3 sprints | — |
| DT-02 | high | Sin tests en módulo de pagos | 2 sprints | Ana |
| ... | | | | |

Recomendación: Incluir DT-01 en el próximo sprint (critical, 3 sprints sin resolver)
```

### Modo `--add`
1. Solicitar: descripción, severidad, componente afectado, estimación
2. Añadir al registro con ID auto-incrementable
3. Sugerir sprint para resolución según capacity

### Modo `--sprint-report`
1. Generar informe de evolución de deuda en el sprint
2. Guardar en `output/debt/YYYYMMDD-debt-{proyecto}.md`

## Integración

- `/kpi:dashboard` → incluye debt ratio como KPI
- `/sprint:plan` → sugiere items de deuda para incluir en sprint
- `/project:audit` → usa debt:track para evaluar salud del proyecto

## Restricciones

- El registro es un fichero markdown en el proyecto, no en Azure DevOps
- Opcionalmente puede crear PBIs de tipo "Tech Debt" en DevOps con `--create-pbi`
- SonarQube es opcional — funciona sin él con registro manual
