---
name: /pdca-cycle
description: >
  Gestión de ciclos PDCA para mejora continua de calidad. Planifica objetivos, registra
  acciones, verifica mediciones, implementa correcciones. Aplicable a calidad clínica,
  mejora de procesos y seguridad del paciente.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /pdca-cycle — Ciclos PDCA para Mejora Continua

Gestiona ciclos Plan-Do-Check-Act para mejora sistemática de procesos y calidad clínica.

## Sintaxis

```bash
/pdca-cycle <subcommand> [opciones]
```

## Subcomandos

### plan
Crear un nuevo ciclo PDCA con objetivos y métricas.

```bash
/pdca-cycle plan --objetivo "Reducir tiempo de espera" \
  --metric "minutos" --target 45 --owner "Dr. García"
```

Genera: `projects/{proyecto}/quality/pdca/PDCA-NNN.yml`

Campos:
- `objetivo`: Descripción clara del objetivo
- `metric`: Métrica a medir
- `target`: Valor objetivo
- `owner`: Responsable del ciclo
- `estado`: plan (inicial)

### do
Registrar acciones ejecutadas en la fase Do.

```bash
/pdca-cycle do --id PDCA-NNN \
  --accion "Implementar nueva secuencia" \
  --fecha "2026-03-06" --responsable "Equipo A"
```

Añade registro con:
- Descripción de acción
- Fecha de ejecución
- Responsable
- Resultado observado

### check
Registrar mediciones y compararlas con el plan.

```bash
/pdca-cycle check --id PDCA-NNN \
  --valor 52 --fecha "2026-03-06"
```

Compara:
- Valor medido vs. baseline
- Valor medido vs. target
- Tendencia vs. ciclos anteriores

### act
Documentar acciones correctivas o preventivas.

```bash
/pdca-cycle act --id PDCA-NNN \
  --accion "Capacitar a operadores" \
  --lecciones "Mejor supervisión necesaria"
```

Registra:
- Acciones correctivas/preventivas
- Lecciones aprendidas
- Cambios permanentes

### status
Mostrar estado actual de un ciclo.

```bash
/pdca-cycle status --id PDCA-NNN
```

Muestra:
- Fase actual (plan/do/check/act)
- Progreso (%)
- Valor actual vs. target
- Responsable

### list
Listar todos los ciclos PDCA.

```bash
/pdca-cycle list [--estado activo|completado]
```

Columnas:
- ID, Objetivo, Fase, Propietario, Progreso

## Almacenamiento

```
projects/{proyecto}/quality/pdca/
  PDCA-001.yml
  PDCA-002.yml
  ...
```

## Aplicaciones

- Calidad clínica
- Mejora de procesos quirúrgicos
- Seguridad del paciente
- Tiempos de espera
