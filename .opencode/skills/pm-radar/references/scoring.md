# PM Radar Scoring

**Última actualización**: 2026-04-14

## Formula

```
score = (urgencia × 3) + (importancia × 3) + (prioridad × 2) + (antiguedad × 2)
```

Max teórico: 90. Bands calibradas en escala real (pesos suman 10).

## Urgencia (0-10)

- 10 — deadline HOY
- 8 — deadline próximas 24-48h
- 6 — esta semana
- 4 — este sprint (2 sem)
- 2 — este mes
- 0 — sin deadline

## Importancia (0-10)

- 10 — bloquea entrega a cliente / compliance
- 8 — bloquea equipo o dependencia crítica
- 6 — compromiso explícito con stakeholder alto (configurado en team/STAKEHOLDERS.md)
- 4 — operativo importante (daily, status)
- 2 — nice to have

## Prioridad (0-10)

- 10 — marcado P1 / blocker / security
- 8 — compromiso roadmap firmado con cliente
- 6 — sprint commitment
- 4 — backlog priorizado
- 2 — idea / pendiente priorizar
- 0 — sin prioridad asignada

## Antigüedad (0-5)

- 5 — abierto >14 días
- 3 — abierto 7-14 días
- 1 — abierto 3-7 días
- 0 — abierto <3 días

## Bands

- **CRITICO** ≥80 → bloquear trabajo hasta resolver
- **URGENTE** 60-79 → abordar hoy
- **IMPORTANTE** 40-59 → esta semana
- **SEGUIMIENTO** <40 → visibilidad, no requiere acción inmediata

## Veto rules (override score)

Si cumple cualquiera, automáticamente CRITICO:
- Deploy fallido en PRE/PRO hoy
- Bug security reportado
- Decline de reunión por stakeholder alto sin alternativa propuesta
- Action item "deliver today" no completado
