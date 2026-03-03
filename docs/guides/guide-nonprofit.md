# Guía: ONG / Organización sin Ánimo de Lucro

> Escenario: ONG de 5–30 personas con voluntarios, proyectos de impacto social, gestión de subvenciones y necesidad de reporting a donantes. Presupuesto limitado para herramientas.

---

## Tu organización

| Rol | Qué necesita | Comandos principales |
|---|---|---|
| **Director/a** | Visión global, reporting a junta y donantes | `/ceo-report`, `/portfolio-overview`, `/ceo-alerts` |
| **Coordinador/a de proyecto** | Gestiona equipos y entregas | `/savia-sprint`, `/savia-board`, `/report-executive` |
| **Responsable de voluntarios** | Onboarding, asignación, seguimiento | `/team-onboarding`, `/savia-directory` |
| **Técnico/a de campo** | Ejecuta actividades, reporta avances | `/flow-task-move`, `/flow-timesheet`, `/savia-send` |
| **Admin / Finanzas** | Justificación de subvenciones, horas | `/flow-timesheet-report`, `/excel-report` |

---

## ¿Por qué Savia para una ONG?

- **Coste cero**: sin licencias. Git + Claude Code es todo lo que necesitas.
- **Justificación de horas**: `/flow-timesheet` genera informes para subvenciones (esencial para fondos públicos).
- **Privacidad**: datos de beneficiarios nunca en el repo (regla PII-Free + cifrado E2E).
- **Trabajo de campo offline**: Travel Mode para zonas sin conexión.
- **Multi-proyecto**: gestiona múltiples programas y subvenciones simultáneamente.

---

## Setup de la organización

### 1. Instalar y crear repo

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

> "Savia, crea un repositorio de empresa para nuestra ONG"

### 2. Definir programas como proyectos

Cada programa o subvención es un proyecto independiente:

```
/savia-pbi create "Formación digital para mayores" --project programa-digital
/savia-pbi create "Distribución de alimentos Q1" --project banco-alimentos
/savia-pbi create "Informe anual para donantes" --project gobernanza
```

### 3. Incorporar equipo y voluntarios

> "Savia, incorpora a vol01 como voluntario en el programa digital"

Para voluntarios: usa alias (no nombres reales) para proteger su privacidad.

---

## Gestión de programas

### Sprint planning adaptado a ONG

Las ONGs no tienen "sprints de software" sino ciclos de actividades. Savia se adapta:

> "Savia, inicia un ciclo de 4 semanas para el programa de formación digital"

```
/savia-sprint start --project programa-digital --goal "10 talleres en 4 centros"
```

**Tasks de un programa social:**

```
/flow-task-create activity "Taller 1: introducción al smartphone (Centro Norte)"
/flow-task-create activity "Taller 2: WhatsApp y videollamadas (Centro Norte)"
/flow-task-create logistics "Preparar materiales para 40 participantes"
/flow-task-create admin "Registro de asistencia taller 1"
/flow-task-create reporting "Informe parcial para el financiador"
```

### Seguimiento diario

> "Savia, ¿cómo va el programa de formación?"

```
/savia-board programa-digital        → Board visual
/flow-burndown                       → Progreso vs. planificado
```

### Registro de horas (justificación de subvenciones)

```
/flow-timesheet TALLER-001 3         → 3h impartiendo taller
/flow-timesheet TALLER-001 1         → 1h preparación
/flow-timesheet-report --monthly     → Informe mensual por persona
```

**Esto es crítico**: muchas subvenciones públicas requieren justificación detallada de horas por actividad y persona. Savia genera estos informes automáticamente.

---

## Comunicación del equipo

### Coordinación con voluntarios

```
/savia-send @vol01 "Recuerda el taller de mañana a las 10:00 en Centro Norte"
/savia-broadcast "Reunión de coordinación el viernes a las 17:00"
/savia-announce "Se cancela el taller del jueves por festivo local"
```

### Reportes de campo

Los técnicos de campo reportan avances directamente:

> "Savia, envía al coordinador: taller completado, 12 asistentes, 2 necesitan seguimiento individual"

La mensajería cifrada E2E protege información sensible sobre beneficiarios.

---

## Reporting para donantes y junta

### Informe ejecutivo

> "Savia, genera el informe trimestral para la junta directiva"

```
/ceo-report --format md              → Informe multi-proyecto
/portfolio-overview                  → Vista global de todos los programas
```

### Informe de impacto

```
/report-executive --project programa-digital
```

Savia genera: actividades completadas, personas atendidas (como métrica, sin datos personales), horas invertidas, progreso vs. objetivos.

### Datos para subvenciones

```
/excel-report time-tracking          → Excel con horas por proyecto/persona
/flow-timesheet-report --monthly     → Desglose mensual
```

---

## Trabajo de campo (offline)

Para zonas rurales o países sin conexión estable:

```
/savia-travel-pack                   → Prepara paquete portable
```

En el terreno, todo funciona offline. Al volver a zona con internet:

```
/savia-travel-init                   → Sincroniza cambios
```

---

## Privacidad de beneficiarios

**Regla fundamental**: los datos de beneficiarios NUNCA entran en el repo.

- Usa métricas agregadas: "12 asistentes", no nombres
- Los identificadores de beneficiarios se gestionan en sistemas externos (bases de datos de la ONG)
- La comunicación interna sobre casos usa alias o códigos
- `/hook-pii-gate.sh` detecta datos personales antes de hacer commit

---

## Gaps detectados y propuestas

| Gap | Descripción | Propuesta |
|---|---|---|
| **Impact metrics** | No hay tracking nativo de métricas de impacto social | `/impact-metric {define\|log\|report}` |
| **Volunteer management** | El onboarding no distingue entre personal fijo y voluntarios | `/volunteer-manage {register\|availability\|hours}` |
| **Grant lifecycle** | Las subvenciones tienen ciclos propios (solicitud → concesión → ejecución → justificación) | `/grant-track {apply\|awarded\|execute\|justify}` |
| **Donor reporting templates** | Los donantes piden formatos específicos | Plantillas de informe por tipo de donante |

---

## Tips

- Cada subvención debe ser un proyecto separado — facilita la justificación de horas
- Registra horas a diario, no al final del mes — la precisión importa para auditorías
- Usa `/savia-broadcast` para comunicaciones generales al equipo
- El board Kanban (`/savia-board`) funciona muy bien en reuniones de coordinación semanales
- Para voluntarios con poca experiencia técnica, el coordinador puede registrar sus horas por ellos
- Travel Mode es especialmente valioso para proyectos de cooperación internacional
