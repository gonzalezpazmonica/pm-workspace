---
name: risk-log
description: >
  Registro estructurado de riesgos del proyecto con probabilidad,
  impacto, mitigación y risk burndown chart.
---

# Risk Log

**Argumentos:** $ARGUMENTS

> Uso: `/risk-log --project {p}` o `/risk-log --project {p} --add`

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--add` — Registrar nuevo riesgo
- `--update {id}` — Actualizar estado/mitigación de un riesgo
- `--close {id}` — Cerrar riesgo (mitigado o materializado)
- `--matrix` — Mostrar matriz probabilidad × impacto
- `--burndown` — Risk burndown chart (evolución por sprint)

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `projects/{proyecto}/risk-register.md` — Registro de riesgos (se crea si no existe)

## Pasos de ejecución

### Modo vista (por defecto)
1. **Leer registro** — `projects/{proyecto}/risk-register.md`
2. **Calcular exposure** — probabilidad × impacto por riesgo
3. **Ordenar** por exposure descendente
4. **Presentar:**

```
## Risk Log — {proyecto} — Sprint {n}

Riesgos abiertos: 6 | Exposure total: 24 | Tendencia: → estable

| ID | Riesgo | Prob | Impacto | Exposure | Mitigación | Owner |
|---|---|---|---|---|---|---|
| R-01 | API proveedor inestable | Alta | Alto | 9 | Circuit breaker + cache | Pedro |
| R-02 | Migración DB sin rollback | Media | Alto | 6 | Script rollback + backup | Ana |
| R-03 | Dependencia de equipo Platform | Alta | Medio | 6 | Slack directo + escalado | PM |
| R-04 | Scope creep en módulo pagos | Media | Medio | 4 | PBI congelados en sprint | PM |
| ... | | | | | | |
```

### Modo `--matrix`
```
         | Bajo(1) | Medio(2) | Alto(3) |
Alta(3)  |         | R-03     | R-01    |
Media(2) |         | R-04     | R-02    |
Baja(1)  | R-06    | R-05     |         |
```

### Modo `--burndown`
1. Leer historial de exposure por sprint
2. Mostrar evolución: riesgos abiertos y exposure total

### Modo `--add`
1. Solicitar: descripción, probabilidad (1-3), impacto (1-3)
2. Solicitar: estrategia mitigación, owner, fecha revisión
3. Añadir con ID auto-incremental (R-XX)

## Integración

- `/sprint-status` → muestra top 3 riesgos por exposure
- `/sprint-plan` → revisa riesgos al planificar
- `/project-release-plan` → riesgos por release
- `/project-audit` → evalúa gestión de riesgos
- `/dependency-map` → riesgos de dependencias cross-team

## Restricciones

- El registro es markdown local, no Azure DevOps
- Con `--create-pbi` puede crear PBIs de mitigación en DevOps
- Probabilidad e impacto: escala 1-3 (bajo/medio/alto)
- Exposure = probabilidad × impacto (máximo 9)
- Revisar riesgos en cada sprint planning (sugerencia automática)
