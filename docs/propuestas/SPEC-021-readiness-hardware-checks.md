---
id: SPEC-021
title: SPEC-021: Readiness Hardware Checks + Zero Telemetry
status: ACCEPTED
origin_date: "2026-03-22"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-021: Readiness Hardware Checks + Zero Telemetry

> Status: **READY** · Fecha: 2026-03-22
> Origen: Project Nomad patterns — hardware benchmarks, zero telemetry declaration
> Impacto: Better sovereignty assessment, trust transparency

---

## Problema

readiness-check.sh verifica software pero no hardware. No sabemos si
la maquina tiene suficiente RAM/disco para vector memory o LLM local.

Además, pm-workspace no declara formalmente su política de telemetría.

## Solucion

### Hardware checks en readiness-check.sh

Nuevo bloque [4b/7] Hardware:
- RAM total >= 4GB (critical para LLM local)
- Disco libre >= 2GB (critical para indices y modelos)
- CPU cores >= 2 (recommended)
- GPU detectada (optional, mejora inference)

### Zero telemetry en README

Seccion "Privacy & Telemetry" declarando:
- Zero telemetry built-in
- No data leaves the machine
- No analytics, no tracking, no phone-home
- Offline-first by design

### Connectivity test en sovereignty-ops.sh

Patron Nomad: test rapido con timeout 3s antes de intentar descargas.

## Tests

- readiness-check muestra hardware info
- README contiene seccion Privacy
- connectivity test retorna 0/1 correctamente
