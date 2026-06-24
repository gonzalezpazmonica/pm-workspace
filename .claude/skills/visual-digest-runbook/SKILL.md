---
name: visual-digest-runbook
description: 5-pass OCR pipeline, homonym protocol, output format and context update rules for visual-digest agent
summary: Runbook for visual-digest (SE-099). 5-pass pipeline, homonym resolution, output schema, context update.
maturity: stable
context: fork
context_cost: medium
---

# Visual Digest — Runbook

Loaded by `visual-digest` for full operational detail.

## Pipeline de 5 Pasadas

**Pasada 1 — Extraccion bruta** (sin contexto): transcribir TODO el texto visible,
marcar dudosos con [?], identificar tipo (pizarra/nota/diagrama/captura/slide). NO resolver.

**Pasada 2 — Carga de contexto** (OBLIGATORIO leer ficheros del proyecto):
- `projects/{p}/CLAUDE.md` — stack, equipos, entornos
- `projects/{p}/team/TEAM.md` + `members/*.md` — equipo completo
- `projects/{p}/reglas-negocio.md` — terminos de dominio
- `projects/{p}/docs/06-seguimiento/*.md` — estado reciente
- `projects/{p}/meetings/_meeting-digest-log.md` — reuniones procesadas

Construir diccionario de resolucion: nombres completos, alias/apodos, homonimos, acronimos.

**Pasada 3 — Resolucion contextual**: por cada [?] buscar en diccionario.
Match unico → `[resuelto: X → Y (fuente: fichero)]`. Ambiguo → evaluar contexto
visual (rol en diagrama, proximidad, estructura). Sin match → hipotesis rankeadas.

**Pasada 4 — Verificacion cruzada**: si la imagen viene de una carpeta de reunion,
leer el digest de esa reunion. Verificar coherencia. Corregir contradicciones.
Incluir seccion "Verificacion cruzada" en el output.

**Pasada 5 — Actualizacion de contexto** (OBLIGATORIA): buscar indice del proyecto
(README.md o CLAUDE.md), identificar docs relevantes, actualizar con Edit,
solo datos no marcados, limite 150 lineas por fichero, registrar en `_digest-log.md`.

## Protocolo de homonimos

Cuando un nombre aparece sin apellido y hay multiples candidatos:
1. Cargar `projects/{p}/agent-memory/visual-digest/homonyms.md` (gitignored, por proyecto)
2. Si no existe: listar candidatos con probabilidad estimada
3. Evaluar: contexto visual, proximidad a otros nombres, rol estructural
4. Elegir mas probable y citar justificacion explicita

## Formato de output

```markdown
# Visual Digest: {nombre_imagen}
- Fuente: {ruta}
- Tipo: pizarra | nota | diagrama | captura | slide
- Confianza global: alta | media | baja
- Contexto cargado: {ficheros leidos en pasada 2}

## Pasada 1 — Extraccion bruta
[transcripcion literal]

## Pasada 3 — Resoluciones
- [resuelto: X → Y (fuente: fichero, justificacion)]
- [ambiguo: X → A (70%) | B (30%), elegido A porque...]
- [?] no resuelto: hipotesis...

## Pasada 4 — Verificacion cruzada
- Coherente con digest de reunion: si/no
- Correcciones aplicadas: [lista]

## Informacion estructurada
[entidades, relaciones, flujos segun tipo]
```

## Reglas

- SIEMPRE las 5 pasadas en orden
- SIEMPRE leer ficheros reales del proyecto en pasada 2 (no usar solo el prompt)
- NUNCA inventar texto que no se ve — marcar [?]
- SIEMPRE citar fuente del fichero para cada resolucion
- SIEMPRE aplicar protocolo de homonimos con nombres ambiguos
- Max 150 lineas por fichero de output

## Memoria y Context Index

- Memoria: `projects/{proyecto}/agent-memory/visual-digest/MEMORY.md`
- Context Index: si existe `projects/{proyecto}/.context-index/PROJECT.ctx` usar `[digest-target]`
