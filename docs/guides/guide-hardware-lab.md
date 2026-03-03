# Guía: Laboratorio de Proyectos de Hardware

> Escenario: equipo de 3–12 personas que diseña, prototipa y fabrica hardware (electrónica, IoT, robótica, dispositivos médicos). Combina firmware, mecánica, PCB y software embebido.

---

## Tu laboratorio

| Rol | Qué hace | Comandos principales |
|---|---|---|
| **Project Lead** | Coordina el producto, sprints, entregas | `/savia-sprint`, `/savia-board`, `/report-executive` |
| **Hardware Engineer** | Diseño PCB, esquemáticos, BOM | `/savia-pbi`, `/flow-task-*`, `/flow-timesheet` |
| **Firmware Developer** | Código embebido (C/C++, Rust) | `/spec-generate`, `/spec-implement`, `/my-focus` |
| **Mechanical Engineer** | CAD, enclosures, tolerancias | `/flow-task-*`, `/savia-send` |
| **QA / Testing** | Validación funcional, EMC, certificaciones | `/qa-dashboard`, `/testplan-generate` |

---

## ¿Por qué Savia para hardware?

Los proyectos de hardware tienen particularidades que Savia gestiona bien:

- **Iteraciones largas**: un sprint de 2 semanas para firmware + un ciclo de 6–8 semanas para PCB. Savia Flow permite sprints de distinta duración por equipo.
- **BOM (Bill of Materials)**: ficheros de seguimiento de componentes, proveedores y costes que viven en Git junto al código.
- **Certificaciones**: tracking de requisitos regulatorios (CE, FCC, UL, RoHS) como PBIs.
- **Firmware + Software**: Savia soporta C/C++, Rust, Python y todos los lenguajes que necesites.
- **Documentación técnica**: specs, datasheets, notas de diseño — todo versionado en Git.

---

## Setup desde cero

### 1. Instalar y crear el repo de empresa

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

> "Savia, crea un repositorio de empresa para el laboratorio"

```
/company-repo
```

### 2. Crear el proyecto de hardware

> "Savia, crea un proyecto llamado sensor-iot en el equipo hardware"

### 3. Estructurar el backlog por disciplina

```
/savia-pbi create "Diseño esquemático del sensor" --project sensor-iot --tag hw
/savia-pbi create "Layout PCB v1" --project sensor-iot --tag hw
/savia-pbi create "Firmware: driver I2C para sensor" --project sensor-iot --tag fw
/savia-pbi create "Enclosure 3D: carcasa IP67" --project sensor-iot --tag mech
/savia-pbi create "App de configuración BLE" --project sensor-iot --tag sw
/savia-pbi create "Certificación CE: documentación EMC" --project sensor-iot --tag cert
```

Usa tags (`hw`, `fw`, `mech`, `sw`, `cert`) para filtrar por disciplina en el board.

---

## Ciclo de desarrollo hardware

### Fase 1 — Concepto (semanas 1–2)

```
/savia-sprint start --project sensor-iot --goal "Definir arquitectura del sistema"
```

**Conversación con Savia:**

> "Savia, necesito descomponer el diseño del sensor en tasks para hardware y firmware"

Savia genera tasks paralelas: esquemático (HW), driver (FW), modelo 3D (MECH), cada una con estimación y dependencias.

**Decisiones arquitectónicas:**

> "Savia, registra que usaremos ESP32-S3 por su BLE 5.0 + WiFi integrado"

```
/adr-create sensor-iot "Selección de MCU: ESP32-S3"
```

### Fase 2 — Prototipo (semanas 3–8)

El board refleja el estado real:

```
/savia-board sensor-iot
```

```
┌──────────┬───────────┬─────────────┬────────┬────────┐
│ Backlog  │ To Do     │ In Progress │ Review │ Done   │
├──────────┼───────────┼─────────────┼────────┼────────┤
│ App BLE  │ PCB v1    │ Driver I2C  │ Esq.   │        │
│ Cert CE  │ Carcasa   │             │        │        │
└──────────┴───────────┴─────────────┴────────┴────────┘
```

**Comunicación cruzada:**

> "Savia, dile a @mech que el conector USB-C necesita 5mm extra de clearance para la antena"

```
/savia-send @mech "El conector USB-C necesita 5mm extra de clearance para la antena BLE. Ver datasheet p.23."
```

### Fase 3 — Validación (semanas 9–12)

```
/testplan-generate --project sensor-iot    → Plan de tests funcionales
/qa-dashboard sensor-iot                    → Estado de calidad
```

**Tracking de certificaciones como PBIs:**

```
/flow-task-create cert "Preparar documentación EMC para CE"
/flow-task-create cert "Ensayo de emisiones conducidas"
/flow-task-create cert "Ensayo de inmunidad ESD"
```

---

## Gestión de BOM

Para el seguimiento de componentes, crea un fichero `bom.md` o `bom.csv` en el proyecto:

> "Savia, registra en el proyecto que hemos seleccionado el sensor BME280 de Bosch, referencia de Mouser 262-BME280"

Savia puede crear y mantener PBIs asociados a la adquisición de componentes:

```
/savia-pbi create "Adquirir BME280 x50 unidades (Mouser)" --project sensor-iot --tag procurement
```

---

## Timesheet por disciplina

```
/flow-timesheet TASK-001 6            → 6h en diseño de PCB
/flow-timesheet TASK-003 4            → 4h en firmware I2C
/flow-timesheet-report --monthly      → Informe de horas por persona y disciplina
```

Útil para: justificación de proyectos de I+D, reporting a inversores, control de costes.

---

## Gaps detectados y propuestas

Al redactar esta guía, se identifican necesidades no cubiertas actualmente:

| Gap | Descripción | Propuesta |
|---|---|---|
| **BOM management** | No hay comando específico para gestionar BOM | `/hw-bom {add\|list\|cost\|export}` |
| **Revision tracking** | Hardware tiene revisiones (Rev A, Rev B) distintas a versiones de software | `/hw-revision {create\|compare\|history}` |
| **Compliance matrix** | Tracking de requisitos regulatorios vs. evidencias | `/compliance-matrix {standard\|status\|export}` |
| **Cross-discipline dependencies** | Las dependencias HW↔FW↔MECH no se modelan bien con tasks lineales | Grafo de dependencias con `/dependency-map` mejorado |

Estos gaps se añaden al roadmap como propuestas para futuras eras.

---

## Tips

- Los proyectos de hardware suelen tener sprints más largos para HW (4 semanas) y más cortos para FW (2 semanas). Savia soporta sprints de distinta duración.
- Versiona los ficheros de diseño (Gerber, STEP, STL) en Git LFS, no directamente en el repo de empresa.
- Usa ADRs (`/adr-create`) para documentar decisiones de componentes — el "por qué" se olvida rápido.
- `/savia-send` es ideal para comunicación técnica cruzada entre disciplinas — queda registrada y buscable.
- Para proyectos regulados (dispositivos médicos, automoción), combina con `/compliance-scan` para tracking de requisitos.
