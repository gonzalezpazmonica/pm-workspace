---
name: pbi-prd
description: >
  Genera un Product Requirements Document (PRD) para un PBI. Lee el JTBD previo
  (si existe) y formaliza los requisitos funcionales, no funcionales, dependencias,
  riesgos y criterios de aceptación enriquecidos. Paso previo a /pbi:decompose.
---

# Generar PRD para un PBI

**PBI ID:** $ARGUMENTS

> Uso: `/pbi:prd 302 --project GestiónClínica`
> Idealmente ejecutar después de `/pbi:jtbd`. Si no hay JTBD, se genera igual
> pero con menos contexto de usuario.

---

## Protocolo

### 1. Leer la skill de referencia

Leer `.claude/skills/product-discovery/SKILL.md`.

### 2. Obtener el PBI de Azure DevOps

```bash
az boards work-item show --id {PBI_ID} --output json
```

### 3. Buscar JTBD previo

```bash
ls projects/{proyecto}/discovery/PBI-{id}-jtbd.md 2>/dev/null
```

Si existe, leerlo y usarlo como base.
Si no existe, informar al usuario que el PRD tendrá menos contexto de usuario
y sugerir ejecutar `/pbi:jtbd {id}` primero.

### 4. Leer contexto del proyecto

- `projects/{proyecto}/CLAUDE.md` — config del proyecto
- `projects/{proyecto}/reglas-negocio.md` — reglas de negocio
- `projects/{proyecto}/equipo.md` — capacidades del equipo (para evaluar viabilidad)

### 5. Generar PRD

Usar la plantilla de `.claude/skills/product-discovery/references/prd-template.md`.

Delegar al agente `business-analyst`:
- Formalizar requisitos funcionales con prioridades (Must/Should/Could)
- Identificar requisitos no funcionales (rendimiento, seguridad, escalabilidad)
- Documentar el scope explícito y lo que queda fuera
- Listar dependencias con otros PBIs o módulos
- Identificar riesgos con probabilidad, impacto y plan de mitigación
- Enriquecer los criterios de aceptación con escenarios Gherkin

### 6. Guardar el PRD

```bash
mkdir -p projects/{proyecto}/discovery
```

Guardar en: `projects/{proyecto}/discovery/PBI-{id}-prd.md`

### 7. Presentar al humano

Mostrar el PRD y preguntar:
- ¿Los requisitos son correctos?
- ¿El scope está bien delimitado?
- ¿Procedo a descomponer en tasks? → sugerir `/pbi:decompose {id}`

---

## Restricciones

- **No incluir estimaciones de tiempo** — eso es para decompose
- **No proponer soluciones técnicas** — solo requisitos de producto
- **No crear tasks en Azure DevOps** — eso es para `/pbi:decompose`
- Si el humano ya validó el JTBD, no repetir preguntas ya respondidas
