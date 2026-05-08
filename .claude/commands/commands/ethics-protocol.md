---
name: ethics-protocol
description: >
  Gestiona protocolos de ética e IRB: creación, aprobación, renovación, vencimiento.
  Rastrea conformidad normativa (humanos, animales, privacidad de datos).
  Vincula a experimentos que dependen del protocolo.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /ethics-protocol {proyecto} {subcommand} {args}

## Subcomandos

- `create {titulo} {tipo} {nivel_riesgo}` — Crea protocolo IRB/ética (human|animal|data-privacy)
- `status {protocol-id} {estado}` — Actualiza estado (draft → submitted → approved/conditional/expired)
- `expire {protocol-id}` — Marca protocolo vencido, alerta experimentos dependientes
- `renew {protocol-id}` — Crea renovación desde protocolo existente
- `list [--status]` — Muestra todos los protocolos con fechas de vencimiento

## Prerequisitos

1. Verificar que `projects/{proyecto}/` existe
2. Crear `projects/{proyecto}/ethics/` si no existe
3. Crear `protocols.json` inicial si no existe (formato: [])
4. Obtener último número protocol: `ls ethics/PROTO-*.md | sort | tail -1`

## Ejecución

1. 🏁 Banner: `══ /ethics-protocol — {proyecto}/{subcommand} ══`
2. **create**: Generar ID (PROTO-NNNN), crear template con: tipo, PI, riesgo, estado=draft, expiry (1 año)
3. **status**: Buscar protocol, validar transición, actualizar, alerta si transitó a expired
4. **expire**: Marcar vencido, buscar experimentos referenciados (EXP-*), generar alerta en agent-notes
5. **renew**: Cargar protocol original, crear PROTO-NNNN-renewal con fecha de inicio nueva, vencimiento +1 año
6. **list**: Tabla con ID, título, tipo, PI, estado, expiry, experimentos vinculados
7. Escribir agent-note: `projects/{proyecto}/agent-notes/ethics-{protocol-id}-{accion}.md`
8. ✅ Banner fin con ID de protocol o lista de renovaciones

## Output

```
projects/{proyecto}/ethics/PROTO-{NNN}-{titulo-slug}.md
projects/{proyecto}/ethics/PROTO-{NNN}-renewal.md (si renew)
```

## Reglas

- Tipos: human_subjects, animal_research, data_privacy
- Niveles riesgo: minimal, low, moderate, high
- Estados: draft, submitted, approved, conditional (con restricciones), expired
- Cada protocol: id, tipo, titulo, PI, descripcion, riesgo, aprobaciones, vencimiento, experimentos vinculados
- Renovación crea nuevo protocol (PROTO-NNN-renewal) con vencimiento +1 año
- expire genera alertas automáticas para todos los EXP-* que referencia este protocol
- list muestra: ID, tipo, estado, vencimiento_fecha, días_restantes, experimentos
