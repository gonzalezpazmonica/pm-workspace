---
name: pbi-jtbd
description: >
  Genera un documento Jobs to be Done (JTBD) para un PBI antes de descomponerlo
  en tasks técnicas. Captura el por qué del usuario: situación, motivación,
  resultado esperado, pain points y criterios de éxito.
---

# Generar JTBD para un PBI

**PBI ID:** $ARGUMENTS

> Uso: `/pbi:jtbd 302 --project GestiónClínica`
> Solo para PBIs tipo feature o user story. No usar para bugs ni chores.

---

## Protocolo

### 1. Leer la skill de referencia

Leer `.claude/skills/product-discovery/SKILL.md` para entender el flujo completo.

### 2. Obtener el PBI de Azure DevOps

```bash
az boards work-item show --id {PBI_ID} --output json
```

Extraer: título, descripción, criterios de aceptación, tipo, comentarios.

### 3. Verificar tipo de PBI

- Si es `Bug` o `Task` → informar al usuario que JTBD no aplica y sugerir `/pbi:decompose` directamente
- Si es `Feature` o `User Story` o `Product Backlog Item` → continuar

### 4. Leer contexto del proyecto

- Leer `projects/{proyecto}/CLAUDE.md`
- Leer `projects/{proyecto}/reglas-negocio.md` si existe
- Identificar reglas de negocio que afecten a este PBI

### 5. Generar JTBD

Usar la plantilla de `.claude/skills/product-discovery/references/jtbd-template.md`.

Delegar al agente `business-analyst` la generación del contenido:
- Traducir la descripción técnica del PBI a un Job Statement centrado en el usuario
- Identificar el contexto, frustración actual y resultado deseado
- Listar los criterios de éxito desde la perspectiva del usuario (no técnicos)
- Listar preguntas sin respuesta que deberían resolverse antes de implementar

### 6. Guardar el JTBD

```bash
mkdir -p projects/{proyecto}/discovery
```

Guardar en: `projects/{proyecto}/discovery/PBI-{id}-jtbd.md`

### 7. Presentar al humano

Mostrar el JTBD generado y preguntar:
- ¿Algún ajuste?
- ¿Procedo a generar el PRD? → sugerir `/pbi:prd {id}`
- ¿O prefieres ir directo a descomponer? → sugerir `/pbi:decompose {id}`

---

## Restricciones

- **No incluir estimaciones de tiempo** — eso es para la fase de decompose
- **No proponer arquitectura técnica** — eso es para el `architect`
- El JTBD es un documento de producto, no de ingeniería
- Si el PBI ya tiene criterios de aceptación detallados, usarlos como base (no ignorarlos)
