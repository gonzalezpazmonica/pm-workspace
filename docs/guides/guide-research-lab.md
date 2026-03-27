# Guía: Laboratorio de Investigación

> Escenario: grupo de investigación en universidad o centro de I+D. Gestiona papers, experimentos, datasets, propuestas de financiación y colaboraciones multi-institucionales.

---

## Tu grupo

| Rol | Qué hace | Comandos principales |
|---|---|---|
| **PI (Investigador Principal)** | Coordina líneas, gestiona financiación | `/ceo-report`, `/savia-sprint`, `/report-executive` |
| **Postdoc / Senior** | Lidera experimentos, supervisa juniors | `/savia-pbi`, `/savia-board`, `/flow-spec-create` |
| **Doctorando** | Ejecuta experimentos, escribe papers | `/my-focus`, `/flow-task-move`, `/flow-timesheet` |
| **Técnico de lab** | Mantiene equipos, procesa muestras | `/flow-task-*`, `/savia-inbox` |
| **Colaborador externo** | Participa en proyectos compartidos | `/savia-send`, `/savia-directory` |

---

## ¿Por qué Savia para investigación?

- **Trazabilidad**: cada decisión, experimento y resultado queda versionado en Git.
- **Reproducibilidad**: las specs SDD documentan procedimientos experimentales reproducibles.
- **Colaboración segura**: mensajería cifrada E2E para datos sensibles.
- **Sin dependencia cloud**: funciona offline (Travel Mode) — ideal para trabajo de campo.
- **Multi-proyecto**: gestiona varias líneas de investigación simultáneamente.

---

## Setup del grupo

### 1. Crear el repositorio del grupo

> "Savia, crea un repositorio de empresa para el grupo de investigación"

```
/company-repo
```

### 2. Definir líneas de investigación como proyectos

```
/savia-pbi create "Paper: efecto X en condiciones Y" --project línea-alpha
/savia-pbi create "Propuesta H2020: convocatoria ABC" --project financiacion
/savia-pbi create "Dataset: recopilación muestras campo" --project línea-beta
```

### 3. Incorporar investigadores

```
/school-enroll inv01                 → Para doctorandos (privacidad por alias)
```

O con perfiles completos para personal fijo:

> "Savia, incorpora a @postdoc1 como investigador senior"

---

## El ciclo de investigación con Savia

### 1. Propuesta de investigación → Sprint "Exploración"

> "Savia, inicia un sprint de exploración para la línea alpha"

```
/savia-sprint start --project línea-alpha --goal "Revisión bibliográfica + hipótesis"
```

**Tasks típicas:**

```
/flow-task-create research "Revisión sistemática: efecto X"
/flow-task-create research "Definir hipótesis H1, H2, H3"
/flow-task-create research "Diseño experimental: variables, controles"
/flow-task-create research "Protocolo de ética (si aplica)"
```

### 2. Experimentación → Sprint "Ejecución"

```
/savia-sprint start --project línea-alpha --goal "Ejecución experimentos batch 1"
```

**Cada experimento como spec:**

> "Savia, crea una spec para el experimento de calibración del sensor a 25°C"

```
/flow-spec-create "Experimento: calibración sensor 25°C"
```

La spec SDD adaptada a investigación incluye: hipótesis, materiales, procedimiento paso a paso, datos esperados, criterios de éxito/fallo. Esto garantiza reproducibilidad.

### 3. Análisis → Sprint "Análisis"

```
/flow-task-create analysis "Procesamiento estadístico batch 1"
/flow-task-create analysis "Visualización de resultados"
/flow-task-create analysis "Validación cruzada con dataset externo"
```

### 4. Publicación → Sprint "Escritura"

```
/flow-task-create writing "Borrador de paper: introducción + métodos"
/flow-task-create writing "Resultados + discusión"
/flow-task-create writing "Revisión interna del grupo"
/flow-task-create writing "Submission a revista"
```

---

## Día a día del PI

### Lunes — Reunión de grupo

> "Savia, dame el estado de todas las líneas de investigación"

```
/portfolio-overview                  → Vista global de todos los proyectos
/savia-board línea-alpha             → Board de la línea alpha
/savia-board línea-beta              → Board de la línea beta
```

### Gestión de financiación

Las propuestas de financiación son proyectos con sus propios sprints:

```
/savia-pbi create "Redactar propuesta técnica" --project h2020-call
/savia-pbi create "Presupuesto y justificación de costes" --project h2020-call
/savia-pbi create "Carta de apoyo: universidad partner" --project h2020-call
```

**Timesheet para justificación de horas:**

```
/flow-timesheet-report --monthly     → Horas por investigador y proyecto
```

Esencial para justificar dedicación en proyectos financiados (H2020, Plan Nacional, etc.).

### Informe para el departamento

```
/report-executive --project línea-alpha
/ceo-report --format md
```

---

## Día a día del doctorando

### Al empezar la jornada

> "Savia, ¿qué tengo pendiente?"

```
/my-focus                            → Tu tarea más prioritaria
/savia-inbox                         → Mensajes del supervisor
```

### Registrar trabajo experimental

```
/flow-task-move EXP-003 in-progress  → Empiezo el experimento
/flow-timesheet EXP-003 5            → 5 horas de lab
/flow-task-move EXP-003 done         → Completado
```

### Comunicar resultados

> "Savia, envía a @pi los resultados del batch 1: todas las muestras por encima del umbral"

```
/savia-send @pi "Resultados batch 1: 23/25 muestras superan umbral (92%). Datos en línea-alpha:resultados/batch1.csv"
```

---

## Diario de laboratorio digital

El diario de lab es fundamental en investigación. Usa `/school-diary` adaptado:

```
/school-diary inv01                  → Entradas del diario del doctorando
```

Cada entrada registra: fecha, experimento, observaciones, datos, conclusiones. Inmutable por estar en Git — válido como evidencia para patentes y publicaciones.

---

## Colaboraciones multi-institucionales

Para proyectos con investigadores de otros centros:

1. El repo de empresa se comparte (GitHub/GitLab privado)
2. Cada colaborador tiene su rama `user/{handle}`
3. La mensajería cifrada E2E protege datos sensibles
4. `/savia-directory` lista todos los participantes

> "Savia, envía a @collab-univ-b los datos anonimizados del estudio piloto"

---

## Gaps detectados y propuestas

| Gap | Descripción | Propuesta |
|---|---|---|
| **Experiment tracking** | No hay entidad nativa "experimento" con metadata (hipótesis, variables, resultados) | `/experiment-log {create\|run\|result\|compare}` |
| **Literature management** | No hay tracking de referencias bibliográficas | `/biblio-add {doi\|bibtex}`, `/biblio-search` |
| **Dataset versioning** | Datasets grandes no encajan en Git | Integración con DVC (Data Version Control) o Git LFS |
| **Grant lifecycle** | Propuestas de financiación tienen ciclos propios (draft → submitted → review → awarded) | `/grant-track {submit\|status\|report}` |
| **Ethics/IRB tracking** | Protocolos de ética no se gestionan como PBIs estándar | `/ethics-protocol {create\|status\|expire}` |

---

## Tips

- Usa sprints largos (4 semanas) para investigación — los ciclos son más lentos que en software
- Las specs SDD son perfectas para documentar protocolos experimentales reproducibles
- `/flow-timesheet` es esencial para justificación de horas en proyectos financiados
- El diario de lab en Git tiene valor legal para disputas de propiedad intelectual
- Para datos sensibles (pacientes, muestras biológicas), la mensajería E2E protege la comunicación
- Los ADRs (`/adr-create`) documentan decisiones metodológicas que se olvidan en 6 meses
