---
name: adr-create
description: >
  Crea un Architecture Decision Record (ADR) para documentar una decisión arquitectónica
  importante. Delega al agente architect para analizar el contexto y producir el ADR.
  Se guarda en projects/{proyecto}/adrs/ con numeración secuencial.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
tier: extended
---

# /adr-create {proyecto} {título}

## Prerequisitos

1. Verificar que `projects/{proyecto}/` existe
2. Crear `projects/{proyecto}/adrs/` si no existe
3. Obtener último número ADR:
   ```bash
   ls projects/$1/adrs/ADR-*.md 2>/dev/null | sort -t'-' -k2 -n | tail -1 | grep -oP 'ADR-\K[0-9]+'
   ```
4. Si no hay ADRs previos, empezar en 001

## Ejecución

1. 🏁 Banner inicio: `══ /adr-create — {proyecto} ══`
2. Calcular siguiente número ADR (NNN con padding a 3 dígitos)
3. Copiar plantilla de `docs/templates/adr-template.md`
4. Sustituir placeholders: ADR-NNN, ticket (si se proporciona), fecha actual
5. Delegar al agente `architect` con Task para:
   - Analizar el contexto del proyecto (CLAUDE.md, código, agent-notes previas)
   - Completar el ADR con: contexto real, decisión, alternativas, consecuencias
6. Guardar en: `projects/{proyecto}/adrs/ADR-{NNN}-{titulo-slug}.md`
7. Escribir agent-note: `projects/{proyecto}/agent-notes/{ticket}-architecture-decision-{fecha}.md`
8. ✅ Banner fin con ruta del ADR creado

## Output

```
projects/{proyecto}/adrs/ADR-{NNN}-{titulo-slug}.md
```

## Reglas

- El architect NO escribe código — solo documenta decisiones
- Si el ADR tiene impacto en seguridad, mencionar que requiere review de security-guardian
- Si el ADR cambia la arquitectura existente, listar ficheros afectados
- Cada ADR es inmutable una vez aceptado — cambios → nuevo ADR que supersede al anterior
