---
name: criticality-frameworks-reference
description: >
  Referencia de frameworks de priorizacion investigados para el sistema
  de criticidad. Comparativa, formulas y recomendaciones de diseño.
type: reference
parent: spec-task-criticality.md
---

# Frameworks de Priorizacion — Referencia

## Comparativa rapida

| Framework | Temporal | Cuantitativo | Escala 100+ | Mejor nivel |
|-----------|----------|-------------|-------------|-------------|
| WSJF (SAFe) | Si (Time Crit.) | Si | Si | Portfolio |
| Cost of Delay | Si (4 perfiles) | Si | Moderado | Estrategico |
| RICE (Intercom) | No nativo | Si | Si | Product backlog |
| ICE | No | Si | Si (rapido) | Experimentos |
| MoSCoW | Timebox | No | No | Sprint/Release |
| Fibonacci+Impact | No | Si | Moderado | Sprint backlog |
| Eisenhower | Binario | No | No | Personal/Daily |
| Kano | No | Survey | No | Discovery |
| Value vs Effort | No | No | Moderado | Triage rapido |

## WSJF (usado en Nivel 1)

`WSJF = (User_Value + Time_Criticality + Risk_Reduction) / Job_Size`
Escala Fibonacci relativa (1-20). Division por tamaño favorece quick wins.
Fortaleza: matematicamente optimo para ordenar backlogs grandes.
Debilidad: requiere sesiones de scoring facilitadas.

## Cost of Delay — 4 perfiles (Reinertsen)

| Perfil | Curva | CoD calculo |
|--------|-------|-------------|
| Standard | Decay lineal | revenue_impact × weeks_delayed |
| Fixed-date | Flat + cliff | penalty / weeks_until_deadline |
| Expedite | Step function | total_loss/hour (prioridad infinita) |
| Intangible | Decay lento | probability × impact × time_horizon |

Fundamento teorico de WSJF. Permite comparar items heterogeneos en $.

## RICE (usado en Nivel 2)

`RICE = (Reach × Impact × Confidence) / Effort`
Reach diferencia de ICE: estima audiencia afectada.
Impact ordinal: 0.25 (minimal) a 3 (massive).
Confidence penaliza especulacion (100/80/50%).

## Confidence decay (diseño propio)

Items sin validacion reciente pierden confianza automaticamente:
14d→1.0, 30d→0.9, 60d→0.75, 90d→0.5, >90d→0.3.
Multiplicador sobre Confidence de RICE. Items olvidados bajan solos.

## Auto-scheduling (patrones observados)

### Reclaim.ai
- Prioridad manual P1-P4 + deadline + duracion estimada
- Scheduler busca huecos respetando meetings existentes
- Items cercanos a deadline se vuelven menos flexibles
- Alerta si tarea no cabe antes de deadline

### Motion
- Algoritmo greedy: max prioridad + min deadline → mejor hueco
- Recomputacion continua ante cualquier cambio
- Alerta proactiva HOY si tarea del jueves no cabra
- Team scheduling con restricciones cruzadas

### Clockwise
- Protege Focus Time agrupando meetings
- Calcula Focus Time Score (% en bloques >=2h)
- Optimizacion a nivel equipo (no solo individual)

## Decisiones de diseño

1. **5 dimensiones vs 4**: añadimos Confianza (de RICE/ICE) y Esfuerzo
   inverso (de WSJF) al modelo original de 4 dimensiones
2. **Perfiles CoD**: en lugar de urgencia lineal generica, clasificamos
   cada item en Standard/Fixed-date/Expedite/Intangible
3. **Confidence decay**: automatiza la limpieza de backlog — items sin
   tocar >90 dias bajan a P3 solos
4. **Nivel 1 WSJF, Nivel 2 RICE**: WSJF es mejor cross-project (tiene
   Job Size como denominador), RICE es mejor intra-proyecto (tiene Reach)
5. **Eisenhower en Nivel 4**: el 2x2 es el unico framework que funciona
   para decision individual rapida (no escala, pero no necesita escalar)
6. **Auto-schedule = Motion pattern**: recomputo continuo ante cambios
   es superior al scheduling unico de Reclaim

## Fuentes

- Reinertsen, *Principles of Product Development Flow* (2009)
- SAFe 6.0 WSJF guidance
- Intercom RICE documentation
- Sean Ellis ICE framework (GrowthHackers)
- Kano et al. (1984) original paper
- Reclaim.ai, Motion, Clockwise engineering docs
