# Reglas Scrum — Directrices del Proceso

> Este documento define las reglas que Claude Code debe aplicar al gestionar el proceso Scrum. Actualizar cuando el equipo acuerde cambios en el proceso.

## Configuración General del Sprint

```
SPRINT_DURATION    = 2 semanas (10 días hábiles)
SPRINT_START_DAY   = Lunes
SPRINT_UNITS       = Story Points (escala Fibonacci)
SPRINT_CAPACITY    = calculada dinámicamente (ver docs/politica-estimacion.md)
```

---

## 1. Sprint Planning

**Cuándo:** Lunes de inicio del sprint, 10:00 — máximo 4h (2h por semana de sprint)

**Reglas:**
- El Sprint Backlog se cierra al final del Planning. No se añaden nuevos items salvo bugs críticos (P1)
- El Sprint Goal debe ser concreto, medible y acordado por todo el equipo
- Cada PBI debe cumplir la **Definition of Ready** antes de entrar al sprint
- Los tasks se crean durante el Planning o en las primeras 24h del sprint
- La capacidad total planificada no debe superar el 85% de la capacity disponible (margen para imprevistos)

**Definition of Ready (DoR):**
- [ ] Descripción clara con criterios de aceptación
- [ ] Story Points estimados por el equipo
- [ ] Sin dependencias bloqueantes externas sin resolver
- [ ] Diseño/prototipo disponible (si aplica)
- [ ] Aprobado por Product Owner

---

## 2. Daily Standup

**Cuándo:** Cada día laborable, 09:15 — máximo 15 minutos

**Formato (3 preguntas):**
1. ¿Qué hice ayer?
2. ¿Qué haré hoy?
3. ¿Tengo algún impedimento?

**Reglas:**
- El Scrum Master facilita, no lidera las respuestas
- Los impedimentos se anotan y se gestionan fuera del Daily
- Si un item lleva >2 días sin avance, el SM lo escala ese mismo día
- Actualizar horas restantes (RemainingWork) en Azure DevOps antes del Daily
- WIP máximo: 2 items por persona en estado Active simultáneamente

---

## 3. Sprint Review

**Cuándo:** Viernes de fin de sprint, 15:00 — máximo 1h

**Agenda:**
1. Demo de items completados (máx. 30 min)
2. Feedback del Product Owner (10 min)
3. Revisión del Sprint Goal: cumplido / parcial / no cumplido (5 min)
4. Actualización del Backlog con el PO (15 min)

**Reglas:**
- Solo se demuestran items en estado Done (que cumplen DoD)
- Los items no completados vuelven al Backlog (no pasan automáticamente al siguiente sprint)
- El PO puede aceptar o rechazar items que estén en "Resolved" pero no pasen la demo
- Registrar velocity del sprint en Azure DevOps antes de cerrar el sprint

---

## 4. Retrospectiva

**Cuándo:** Viernes de fin de sprint, 16:30 — máximo 90 minutos

**Formato por defecto:** Start / Stop / Continue (adaptable por el equipo)

**Reglas:**
- Obligatoria revisión de action items de la retro anterior (¿se cumplieron?)
- Máximo 3-4 action items por retrospectiva (priorizad sobre cantidad)
- Cada action item debe tener: qué, quién, cuándo
- Los action items se crean como Tasks en Azure DevOps con tag `retro-action`
- Blameless: se habla de procesos y sistemas, no de personas

---

## 5. Refinement (Grooming)

**Cuándo:** Miércoles de la semana 1 del sprint, 11:00 — máximo 2h

**Objetivo:** Preparar el backlog para el siguiente sprint (DoR)

**Reglas:**
- Estimar items del backlog con Planning Poker
- Descomponer PBIs grandes (> 13 SP) en items más pequeños
- Actualizar y limpiar el backlog: archivar items obsoletos, re-priorizar
- Participación obligatoria: SM + PO + al menos 50% del equipo técnico

---

## 6. Definition of Done (DoD)

Un item se considera Done cuando cumple **TODOS** estos criterios:

### Para User Stories / PBIs:
- [ ] Código desarrollado y commiteado con referencia AB#XXXX
- [ ] Pull Request aprobado por al menos 1 revisor
- [ ] Tests unitarios escritos y pasando (cobertura mínima: 80%)
- [ ] Tests de integración pasando en pipeline CI
- [ ] Code review completado sin comentarios bloqueantes
- [ ] Documentación técnica actualizada (si aplica)
- [ ] Desplegado en entorno de test/staging
- [ ] Demo aprobada por Product Owner
- [ ] Sin bugs P1/P2 abiertos relacionados

### Para Tasks:
- [ ] Criterios de aceptación de la task cumplidos
- [ ] RemainingWork = 0 en Azure DevOps
- [ ] Código mergeado al branch principal del sprint

### Para Bugs:
- [ ] Reproducción documentada y resuelta
- [ ] Test de regresión añadido
- [ ] Verificado en entorno de test
- [ ] Root cause documentado en el work item

---

## 7. WIP Limits

| Nivel | Límite | Alerta |
|-------|--------|--------|
| Por persona (Active simultáneamente) | 2 items | Notificar en Daily |
| Por columna del board (In Review) | 3 items | Bloquear nuevas entradas |
| Por columna del board (Active) | 5 items | Notificar al SM |
| Bugs P1 sin asignar | 0 | Asignar inmediatamente |

---

## 8. Escalado de Impedimentos

| Tipo | Tiempo máximo sin resolver | Escalado a |
|------|---------------------------|------------|
| Técnico interno | 2 días | Tech Lead |
| Dependencia externa | 1 día | PM / PO |
| Bloqueante de sprint goal | Inmediato | SM + PO + Dirección |
| Bug P1 en producción | Inmediato | Todos + Dirección |

---

## 9. Convenciones de Azure DevOps

- **Nomenclatura de sprints:** `Sprint YYYY-NN` (ej: `Sprint 2026-04`)
- **IterationPath:** `[Proyecto]\Sprints\Sprint YYYY-NN`
- **Tags obligatorios en bugs:** severidad (`P1`,`P2`,`P3`), origen (`regression`,`new-feature`)
- **Tags de retro:** `retro-action` en tasks generadas en retrospectiva
- **Tags de bloqueo:** `blocked` + comentario explicando el bloqueo
- **CompletedWork:** actualizar diariamente (antes del Daily)
- **RemainingWork:** actualizar diariamente (refleja trabajo pendiente real, no estimación inicial)
