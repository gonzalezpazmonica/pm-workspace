# Cómo Usar el Workspace

## Gestión de Sprint

Ejecuta estos comandos dentro de Claude Code:

| Comando | Descripción |
|---------|-------------|
| `/sprint-status` | Estado del sprint: burndown, items activos, alertas de WIP |
| `/sprint-plan` | Asistente de Sprint Planning: capacity + PBIs candidatos del backlog |
| `/sprint-review` | Resumen para Sprint Review: velocity, items completados, demostración |
| `/sprint-retro` | Plantilla de retrospectiva con datos del sprint |

---

## Ejemplo — Lunes por la mañana antes de la Daily

_Escenario: Sprint en curso, día 4 de 10. Quieres saber si el equipo va bien antes de la reunión._

**Tú escribes:**
```
/sprint-status --project GestiónClínica
```

**Claude responde:**
```
══════════════════════════════════════════════════
  Sprint 2026-04 · GestiónClínica · Día 4/10
  Objetivo: Módulo de Citas — CRUD completo + notificaciones
══════════════════════════════════════════════════

  Burndown (SP)
  Ideal:  ▓▓▓▓▓▓▓░░░░░░░░░░░░░  38 → 0
  Real:   ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░  38 → 23 completados  ⚠️
  → Lleváis 15 SP completados, deberían ser 15.2 → ✅ en línea

  En progreso (5 items):
    AB#2041  POST /citas endpoint           Laura S.    [4/6h] ✅ en plazo
    AB#2042  CitaValidator FluentValidation  🤖 agente   [terminado, en review]
    AB#2043  Unit tests CitaService         🤖 agente   [en ejecución, 2h]
    AB#2044  Migración tabla Citas          Carlos TL   [0/4h] 🔴 sin avance
    AB#2045  GET /citas?fecha query         Diego T.    [2/4h] ✅

  🔴 Requiere atención:
    • AB#2044 — Carlos no ha registrado avance en 2 días.
      Riesgo: si no avanza hoy, la migración puede bloquear a Laura y Diego.
      Acción sugerida: preguntar en Daily si está bloqueado.

  🟡 Avisos:
    • 3 PBIs todavía en estado "New" sin descomponer → ¿planeas abordarlos este sprint?
    • Ana (QA) tiene 0h imputadas esta semana — confirmar que está activa

  Capacidad restante: ~72h humanas | ~18h agente
  Estimación de cierre: 🟡 RIESGO MODERADO — depende de la migración
```

**Tú escribes:**
```
Dame el punto exacto para comentar en la Daily sobre AB#2044
```

**Claude responde:**
```
Para la Daily sobre AB#2044 (Migración tabla Citas):

"Carlos, AB#2044 lleva 2 días sin avance. ¿Está bloqueado?
 Esta migración desbloquea a Laura para hacer las queries de Citas
 y a Diego para las relaciones EF Core. Si hay algún problema
 con el schema, lo resolvemos ahora antes de que se convierta en cuello de botella."

Si Carlos confirma un bloqueo, puedo ayudarte a:
  a) Redefinir el scope de la migración para que sea más sencilla
  b) Reasignar a alguien con más disponibilidad esta semana
  c) Mover AB#2044 al siguiente sprint y adaptar las dependencias
```

---

## Ejemplo — Sprint Planning completo

_Escenario: Es el viernes antes del nuevo sprint. Quieres preparar el planning._

**Tú escribes:**
```
/sprint-plan --project GestiónClínica
```

**Claude responde:**
```
══════════════════════════════════════════
  Sprint Planning · 2026-05
  GestiónClínica Team
══════════════════════════════════════════

  CAPACIDAD DEL SPRINT
  ┌──────────────────┬───────┬──────────┬────────┬──────────────┐
  │ Persona          │ Días  │ h/día    │ Factor │ Cap. Efectiva│
  ├──────────────────┼───────┼──────────┼────────┼──────────────┤
  │ Carlos TL        │  9    │  6.0h    │  0.75  │  40.5h       │
  │ Laura Sánchez    │ 10    │  7.5h    │  0.75  │  56.3h       │
  │ Diego Torres     │  9    │  7.5h    │  0.75  │  50.6h       │
  │ Ana Morales (QA) │ 10    │  7.5h    │  0.75  │  56.3h       │
  │ 🤖 Agente Claude │  —    │   —      │   —    │  ~35h est.   │
  └──────────────────┴───────┴──────────┴────────┴──────────────┘
  Total humano: 203.7h | Velocidad histórica: 38 SP

  PBIs CANDIDATOS (ordenados por prioridad en backlog)
  ┌──────┬────────────────────────────────────┬─────┬────────┐
  │  ID  │ Título                             │ SP  │ h est. │
  ├──────┼────────────────────────────────────┼─────┼────────┤
  │ #301 │ Notificaciones de cita por email   │  8  │  38h   │
  │ #302 │ Historial de citas por paciente    │  5  │  24h   │
  │ #303 │ Panel de administración de salas   │  8  │  36h   │
  │ #304 │ Exportar agenda a PDF              │  3  │  14h   │
  │ #305 │ API paginación en listados         │  2  │   8h   │ ← límite capacity
  └──────┴────────────────────────────────────┴─────┴────────┘
  Propuesta: #301 + #302 + #304 + #305 = 18 SP / 84h ✅ dentro de capacity
  (El #303 queda fuera — 36h excede la capacidad restante)

  ¿Procedo a descomponer estos 4 PBIs en tasks con asignaciones?
```

**Tú escribes:**
```
Sí, descompón los 4 PBIs y asigna
```

**Claude responde:**
```
Descomponiendo los 4 PBIs... [consulta Azure DevOps]

PBI #301 — Notificaciones de cita por email (8 SP)
  B1  Entidad NotificacionEmail + reglas de dominio   4h  Carlos TL   human
  B2  IEmailNotificationService interface             2h  Carlos TL   human
  B3  SendCitaConfirmationCommandHandler              4h  🤖 agente   agent-single
  B4  EmailTemplateService (Infrastructure)          3h  🤖 agente   agent-single
  C1  Unit tests del command handler                 2h  🤖 agente   agent-single
  D1  EmailController endpoints                      3h  🤖 agente   agent-single
  D2  Integration test (Mailtrap sandbox)            4h  Diego T.    human
  E1  Code Review                                    2h  Carlos TL   human

[...PBIs #302, #304, #305 igualmente descompuestos...]

Resumen de asignación:
  Carlos TL:  22h (54% capacity) ✅
  Laura S.:   18h (32% capacity) 🟡 tiene margen, ¿añadir #303 parcialmente?
  Diego T.:   24h (47% capacity) ✅
  Ana QA:     20h (35% capacity) ✅
  🤖 Agente:  28h estimadas ($18 USD est.)

¿Creo las tasks en Azure DevOps con estas asignaciones?
```

---

## Informes

| Comando | Descripción |
|---------|-------------|
| `/report-hours` | Informe de imputación de horas (Excel, 4 pestañas) |
| `/report-executive` | Informe ejecutivo multi-proyecto (Word + PPT con semáforos) |
| `/report-capacity` | Estado de capacidades del equipo esta semana |
| `/team-workload` | Mapa de carga de trabajo por persona |
| `/kpi-dashboard` | Dashboard completo: velocity, cycle time, lead time, bug escape rate |

---

## Ejemplo — Informe de horas al cierre del sprint

_Escenario: Último día del sprint. El cliente pide el informe de imputación._

**Tú escribes:**
```
/report-hours --project GestiónClínica --sprint 2026-04
```

**Claude responde:**
```
Generando informe de horas para Sprint 2026-04...
[Consultando Azure DevOps Work Items y time tracking]
[Consultando capacidades e imputaciones del sprint]

✅ Informe generado: output/reports/GestionClinica-horas-2026-04.xlsx

Resumen ejecutivo:
  Horas planificadas:  203.7h
  Horas imputadas:     198.3h (97.3%)
  Horas de agente:      31.5h (equivalente real: ~$19.80 USD)

  Por persona:
    Carlos TL   → 39.0h / 40.5h (96%) ✅
    Laura S.    → 54.5h / 56.3h (97%) ✅
    Diego T.    → 52.0h / 50.6h (103%) ⚠️ +2.4h sobre capacity
    Ana QA      → 52.8h / 56.3h (94%) ✅

  Items completados: 9/11 (18/20 SP — velocity 18 vs histórico 38 🔴)
  Items arrastrados al siguiente sprint: AB#2044, AB#2051

El Excel tiene 4 pestañas: Resumen, Detalle por persona, Detalle por PBI, Agentes.
```

**Nota:** El fichero `.xlsx` se puede entregar directamente al cliente o al PMO.

---

## Ejemplo — Ver la carga real del equipo esta semana

_Escenario: Miércoles. Sospechas que alguien está sobrecargado._

**Tú escribes:**
```
/team-workload --project GestiónClínica
```

**Claude responde:**
```
Carga del equipo — semana actual (lun 17/03 – vie 21/03)

  Carlos TL    ██████████░░░░░  68%  [ 20.4h / 30h disponibles ]  🟢
  Laura S.     █████████████░░  87%  [ 32.8h / 37.5h ]            🟡 alta
  Diego T.     ████████████████ 100% [ 37.5h / 37.5h ]            🔴 sin margen
  Ana QA       ████████░░░░░░░  55%  [ 20.6h / 37.5h ]            🟢 tiene margen
  🤖 Agente    ███████░░░░░░░░  48%  [ 3 specs en cola ]          🟢

  ⚠️  Diego Torres está al 100% — no absorbe incidencias ni bugs inesperados.
  💡 Ana tiene 16.9h disponibles esta semana. Si hay tareas pendientes
     de QA o documentación, ahora es el momento de asignárselas.
```

---

## Descomposición de PBIs

El proceso estándar para preparar un sprint:

1. `/pbi-decompose {id}` — Claude analiza el PBI, sus criterios de aceptación y el contexto del equipo, y propone la tabla de tasks.
2. Claude pregunta si crear las tasks en Azure DevOps.
3. Confirmas y Claude las crea vía REST API.

Para preparar el sprint completo de una vez: `/pbi-plan-sprint` hace todo el ciclo automáticamente (capacity → selección de PBIs → descomposición → asignación → creación en AzDO).

**Algoritmo de scoring de asignación:**
```
score = expertise × 0.40 + disponibilidad × 0.30 + balance × 0.20 + crecimiento × 0.10
```
Los pesos son configurables por proyecto en `projects/{proyecto}/CLAUDE.md`.

---

## Ejemplo — Descomponer un PBI con criterios de aceptación

_Escenario: Tienes el PBI AB#302 "Historial de citas por paciente" con 3 criterios de aceptación definidos en Azure DevOps._

**Tú escribes:**
```
/pbi-decompose 302 --project GestiónClínica
```

**Claude responde:**
```
Analizando AB#302 — "Historial de citas por paciente" (5 SP)

Criterios de aceptación detectados:
  ✓ El médico puede filtrar por rango de fechas (inicio–fin)
  ✓ Se muestran máx. 50 resultados con paginación (cursor-based)
  ✓ Incluye estado de cada cita: Confirmada / Cancelada / Realizada

Stack detectado: .NET 8 / Clean Arch / CQRS / EF Core / xUnit  ← (detectado automáticamente por Language Pack)

PROPUESTA DE TASKS:
┌────┬──────────────────────────────────────────┬──────┬──────┬──────────────┬───────────────┐
│ #  │ Task                                     │ Horas│ Act. │ Asignado a   │ Developer Type│
├────┼──────────────────────────────────────────┼──────┼──────┼──────────────┼───────────────┤
│ B1 │ Diseño query HistorialCitasQuery + DTO   │  3h  │ Dev  │ Carlos TL    │ human         │
│ B2 │ EF Core: IHistorialCitasRepository       │  2h  │ Dev  │ Diego T.     │ human         │
│ B3 │ GetHistorialCitasQueryHandler            │  4h  │ Dev  │ 🤖 agente    │ agent-single  │
│ C1 │ HistorialCitasController (GET endpoint)  │  3h  │ Dev  │ 🤖 agente    │ agent-single  │
│ C2 │ Paginación cursor-based (middleware)     │  3h  │ Dev  │ Laura S.     │ human         │
│ D1 │ Unit tests del QueryHandler              │  2h  │ Dev  │ 🤖 agente    │ agent-single  │
│ D2 │ Integration test end-to-end              │  3h  │ QA   │ Ana Morales  │ human         │
│ E1 │ Code Review                              │  2h  │ Rev  │ Carlos TL    │ human         │
└────┴──────────────────────────────────────────┴──────┴──────┴──────────────┴───────────────┘
Total: 22h | Agente: 9h ($5.40 USD est.) | Humano: 13h

Nota: La paginación cursor-based (C2) es un patrón nuevo en este proyecto
→ asignada a Laura (Full Stack, más flexible) en lugar de al agente.

¿Creo estas Tasks en Azure DevOps? (S/N o ajusta lo que necesites)
```

**Tú escribes:**
```
Cambia C2 al agente también, Laura ya tiene mucha carga. Crea las tasks.
```

**Claude responde:**
```
Ajustado: C2 → agent-single (añadiré en la spec el patrón de paginación de referencia).

Creando 8 tasks en Azure DevOps para AB#302...
  ✅ AB#302-B1 creada → asignada a Carlos Mendoza
  ✅ AB#302-B2 creada → asignada a Diego Torres
  ✅ AB#302-B3 creada → asignada a claude-agent (tag: spec-driven)
  ✅ AB#302-C1 creada → asignada a claude-agent (tag: spec-driven)
  ✅ AB#302-C2 creada → asignada a claude-agent (tag: spec-driven)
  ✅ AB#302-D1 creada → asignada a claude-agent-fast (tag: spec-driven)
  ✅ AB#302-D2 creada → asignada a Ana Morales
  ✅ AB#302-E1 creada → asignada a Carlos Mendoza

8 tasks creadas. Las tasks de agente (B3, C1, C2, D1) ya tienen el tag
"spec-driven" y están listas para /spec-generate cuando quieras.
```

---
