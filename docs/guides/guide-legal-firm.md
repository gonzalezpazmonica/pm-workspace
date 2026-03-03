# Guía: Bufete de Abogados / Despacho Legal

> Escenario: despacho de 3–20 profesionales que gestiona casos, expedientes, plazos legales y documentación voluminosa. Requiere confidencialidad extrema y trazabilidad.

---

## Tu despacho

| Rol | Qué necesita | Comandos principales |
|---|---|---|
| **Socio/a director/a** | Visión global, facturación, reporting | `/ceo-report`, `/portfolio-overview`, `/flow-timesheet-report` |
| **Abogado/a senior** | Gestiona casos, supervisa juniors | `/savia-sprint`, `/savia-board`, `/savia-pbi` |
| **Abogado/a junior** | Ejecuta tareas, investiga, redacta | `/my-focus`, `/flow-task-move`, `/flow-timesheet` |
| **Paralegal** | Documentación, filing, plazos | `/flow-task-*`, `/savia-inbox` |
| **Secretaría / Admin** | Agenda, facturación, comunicaciones | `/flow-timesheet-report`, `/excel-report` |

---

## ¿Por qué Savia para un bufete?

- **Confidencialidad**: cifrado E2E (RSA-4096 + AES-256-CBC) para comunicaciones internas sobre casos.
- **Timesheet para facturación**: registro de horas por caso/tarea, esencial para facturación por horas.
- **Trazabilidad**: cada documento, decisión y comunicación queda versionada en Git.
- **Gestión de plazos**: deadlines legales como tasks con fechas críticas.
- **Offline**: Travel Mode para tribunales, viajes a cliente, zonas sin cobertura.

---

## Setup del despacho

### 1. Instalar y crear repo

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

> "Savia, crea un repositorio para el despacho"

### 2. Estructura por áreas de práctica

Cada área es un "equipo" y cada caso un "proyecto":

```
/savia-team init --name mercantil
/savia-team init --name laboral
/savia-team init --name penal
```

### 3. Crear un caso

> "Savia, crea un nuevo caso en el área mercantil"

```
/savia-pbi create "Caso: reclamación de cantidad — expediente 2026-M-0042" --project mercantil
```

**Tasks del caso:**

```
/flow-task-create investigation "Análisis de documentación aportada por el cliente"
/flow-task-create drafting "Redacción de demanda"
/flow-task-create filing "Presentación telemática en juzgado"
/flow-task-create hearing "Preparación de vista oral"
/flow-task-create deadline "PLAZO: contestación a la demanda — 20 días hábiles"
```

---

## Gestión de casos como sprints

Cada caso tiene su propio ritmo. Usa sprints flexibles:

### Caso rápido (requerimiento, reclamación)

```
/savia-sprint start --project caso-2026-M-0042 --goal "Demanda presentada en plazo"
```

Sprint de 2–4 semanas con deadline fijo.

### Caso largo (litigio, procedimiento concursal)

Divide en fases como sprints:

```
Sprint 1: "Fase de alegaciones"
Sprint 2: "Fase probatoria"
Sprint 3: "Conclusiones + vista"
Sprint 4: "Sentencia + recurso"
```

### El board del caso

```
/savia-board caso-2026-M-0042
```

```
┌──────────┬───────────┬─────────────┬────────┬────────┐
│ Pendiente│ En curso  │ En revisión │ Filing │ Hecho  │
├──────────┼───────────┼─────────────┼────────┼────────┤
│ Prueba   │ Demanda   │ Análisis    │        │ Docs   │
│ Vista    │           │ doc.        │        │ client │
└──────────┴───────────┴─────────────┴────────┴────────┘
```

---

## Timesheet y facturación

**El registro de horas es el corazón del negocio de un bufete.**

### Registrar horas

```
/flow-timesheet TASK-001 2.5         → 2.5h en redacción de demanda
/flow-timesheet TASK-002 1           → 1h revisando documentación
/flow-timesheet TASK-003 0.5         → 30min en llamada con cliente
```

### Informes de facturación

```
/flow-timesheet-report --monthly     → Horas por abogado/caso/mes
/excel-report time-tracking          → Excel para contabilidad
```

> "Savia, genera el informe de horas del caso 2026-M-0042 para facturar al cliente"

Savia produce un desglose: fecha, abogado, tarea, horas, descripción — listo para adjuntar a la factura.

---

## Comunicación confidencial

### Sobre un caso sensible

```
/savia-send @senior1 "Caso 0042: el perito confirma la versión del cliente. Adjunto el informe en la rama del caso."
```

Todo cifrado E2E. Ni siquiera un administrador del repo puede leer los mensajes sin las claves privadas.

### Coordinación del despacho

```
/savia-announce "Reunión de socios el viernes a las 13:00. Orden del día en el board de gobernanza."
/savia-broadcast "Recordatorio: cierre de timesheet mensual el día 30"
```

---

## Control de plazos

Los plazos legales son innegociables. Modélalos como tasks con prioridad máxima:

```
/flow-task-create deadline "PLAZO FATAL: recurso de apelación — 20 días"
```

> "Savia, ¿qué plazos tenemos esta semana?"

Savia filtra las tasks de tipo deadline y las muestra ordenadas por urgencia.

---

## Día a día del abogado junior

### Mañana

> "Savia, ¿qué tengo para hoy?"

```
/my-focus                            → Tarea más prioritaria
/savia-inbox                         → Instrucciones del senior
```

### Durante el día

```
/flow-task-move TASK-005 in-progress → Empiezo investigación
/flow-timesheet TASK-005 3           → 3h de research
/flow-task-move TASK-005 review      → Paso al senior para revisión
```

### Al terminar

```
/savia-send @senior1 "Terminé el análisis del TASK-005. He encontrado 3 sentencias favorables del TS."
```

---

## Reporting para socios

### Carga de trabajo del despacho

```
/portfolio-overview                  → Todos los casos activos
/ceo-alerts                          → Solo alertas críticas (plazos, bloqueos)
```

### Métricas de productividad

```
/ceo-report                          → Informe ejecutivo
/velocity-trend                      → Tendencia de resolución de casos
```

---

## Gaps detectados y propuestas

| Gap | Descripción | Propuesta |
|---|---|---|
| **Deadline management** | No hay entidad nativa "plazo legal" con alarmas | `/legal-deadline {set\|list\|alert}` con notificaciones |
| **Court calendar** | Integración con calendarios de juzgados | `/court-calendar {import\|sync}` |
| **Conflict check** | Verificar conflictos de intereses antes de aceptar caso | `/conflict-check {client\|matter}` |
| **Document templates** | Plantillas de escritos judiciales | `/legal-template {demanda\|contestacion\|recurso}` |
| **Billing rates** | Tasas por hora diferenciadas por abogado/tipo | `/billing-rate {set\|calculate\|invoice}` |

---

## Tips

- Cada caso es un proyecto separado — nunca mezcles expedientes
- Registra horas en el momento, no al final del día — la precisión es dinero
- Usa `/savia-send` para instrucciones sobre casos — queda registrado y cifrado
- Los plazos legales SIEMPRE como tasks de máxima prioridad
- Cifrado E2E es especialmente importante aquí: secreto profesional es obligación deontológica
- Para despachos con múltiples sedes, Company Savia permite colaboración segura sin VPN
