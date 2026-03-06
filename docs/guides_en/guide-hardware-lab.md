# Guide: Hardware Projects Laboratory

> Scenario: team of 3–12 people that designs, prototypes and manufactures hardware (electronics, IoT, robotics, medical devices). Combines firmware, mechanics, PCB and embedded software.

---

## Your laboratory

| Role | What they do | Main commands |
|---|---|---|
| **Project Lead** | Coordinates product, sprints, deliveries | `/savia-sprint`, `/savia-board`, `/report-executive` |
| **Hardware Engineer** | PCB design, schematics, BOM | `/savia-pbi`, `/flow-task-*`, `/flow-timesheet` |
| **Firmware Developer** | Embedded code (C/C++, Rust) | `/spec-generate`, `/spec-implement`, `/my-focus` |
| **Mechanical Engineer** | CAD, enclosures, tolerances | `/flow-task-*`, `/savia-send` |
| **QA / Testing** | Functional validation, EMC, certifications | `/qa-dashboard`, `/testplan-generate` |

---

## Why Savia for hardware?

Hardware projects have particularities that Savia handles well:

- **Long iterations**: a 2-week firmware sprint plus a 6–8 week PCB cycle. Savia Flow allows sprints of different duration per team.
- **BOM (Bill of Materials)**: component tracking files, suppliers and costs that live in Git alongside code.
- **Certifications**: tracking regulatory requirements (CE, FCC, UL, RoHS) as PBIs.
- **Firmware + Software**: Savia supports C/C++, Rust, Python and all languages you need.
- **Technical documentation**: specs, datasheets, design notes — all versioned in Git.

---

## Setup from scratch

### 1. Install and create the company repo

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

> "Savia, create an enterprise repository for the laboratory"

```
/company-repo
```

### 2. Create the hardware project

> "Savia, create a project called sensor-iot for the hardware team"

### 3. Structure the backlog by discipline

```
/savia-pbi create "Design sensor schematic" --project sensor-iot --tag hw
/savia-pbi create "PCB Layout v1" --project sensor-iot --tag hw
/savia-pbi create "Firmware: I2C driver for sensor" --project sensor-iot --tag fw
/savia-pbi create "3D Enclosure: IP67 housing" --project sensor-iot --tag mech
/savia-pbi create "BLE Configuration App" --project sensor-iot --tag sw
/savia-pbi create "CE Certification: EMC documentation" --project sensor-iot --tag cert
```

Use tags (`hw`, `fw`, `mech`, `sw`, `cert`) to filter by discipline on the board.

---

## Hardware development cycle

### Phase 1 — Concept (weeks 1–2)

```
/savia-sprint start --project sensor-iot --goal "Define system architecture"
```

**Conversation with Savia:**

> "Savia, I need to break down the sensor design into tasks for hardware and firmware"

Savia generates parallel tasks: schematic (HW), driver (FW), 3D model (MECH), each with estimation and dependencies.

**Architectural decisions:**

> "Savia, record that we're using ESP32-S3 for its integrated BLE 5.0 + WiFi"

```
/adr-create sensor-iot "MCU Selection: ESP32-S3"
```

### Phase 2 — Prototype (weeks 3–8)

The board reflects the actual state:

```
/savia-board sensor-iot
```

```
┌──────────┬───────────┬─────────────┬────────┬────────┐
│ Backlog  │ To Do     │ In Progress │ Review │ Done   │
├──────────┼───────────┼─────────────┼────────┼────────┤
│ App BLE  │ PCB v1    │ Driver I2C  │ Schem. │        │
│ Cert CE  │ Housing   │             │        │        │
└──────────┴───────────┴─────────────┴────────┴────────┘
```

**Cross-team communication:**

> "Savia, tell @mech that the USB-C connector needs 5mm extra clearance for the antenna"

```
/savia-send @mech "The USB-C connector needs 5mm extra clearance for the BLE antenna. See datasheet p.23."
```

### Phase 3 — Validation (weeks 9–12)

```
/testplan-generate --project sensor-iot    → Functional test plan
/qa-dashboard sensor-iot                    → Quality status
```

**Tracking certifications as PBIs:**

```
/flow-task-create cert "Prepare EMC documentation for CE"
/flow-task-create cert "Conducted emissions test"
/flow-task-create cert "ESD immunity test"
```

---

## BOM management

For component tracking, create a `bom.md` or `bom.csv` file in the project:

> "Savia, record that we've selected the BME280 sensor from Bosch, Mouser reference 262-BME280"

Savia can create and maintain PBIs associated with component procurement:

```
/savia-pbi create "Procure BME280 x50 units (Mouser)" --project sensor-iot --tag procurement
```

---

## Timesheet by discipline

```
/flow-timesheet TASK-001 6            → 6h in PCB design
/flow-timesheet TASK-003 4            → 4h in firmware I2C
/flow-timesheet-report --monthly      → Report of hours by person and discipline
```

Useful for: justification of R&D projects, reporting to investors, cost control.

---

## Gaps identified and proposals

In writing this guide, needs not currently covered were identified:

| Gap | Description | Proposal |
|---|---|---|
| **BOM management** | No specific command for BOM management | `/hw-bom {add\|list\|cost\|export}` |
| **Revision tracking** | Hardware has revisions (Rev A, Rev B) different from software versions | `/hw-revision {create\|compare\|history}` |
| **Compliance matrix** | Tracking regulatory requirements vs. evidence | `/compliance-matrix {standard\|status\|export}` |
| **Cross-discipline dependencies** | HW↔FW↔MECH dependencies not well modeled with linear tasks | Dependency graph with improved `/dependency-map` |

These gaps are added to the roadmap as proposals for future eras.

---

## Tips

- Hardware projects typically have longer sprints for HW (4 weeks) and shorter for FW (2 weeks). Savia supports sprints of different duration.
- Version design files (Gerber, STEP, STL) in Git LFS, not directly in the company repo.
- Use ADRs (`/adr-create`) to document component decisions — the "why" is forgotten quickly.
- `/savia-send` is ideal for cross-discipline technical communication — it's recorded and searchable.
- For regulated projects (medical devices, automotive), combine with `/compliance-scan` for requirements tracking.
