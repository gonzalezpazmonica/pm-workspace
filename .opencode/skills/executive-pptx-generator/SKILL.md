---
name: executive-pptx-generator
description: Genera presentaciones PPTX para audiencia directiva (≥95/100) desde notas, transcripción o spec. Aplica pyramid principle, una idea por slide, jerarquía tipográfica real, iconos+imágenes en cada slide, paleta corporativa cliente. Usar cuando se pide PPT para C-level, comité, SteerCo o demo a cliente.
maturity: stable
context: fork
context_cost: medium
category: "communication"
tags: ["pptx", "presentation", "executive", "design", "mcp-powerpoint"]
priority: "medium"
---

# Skill: Executive PPTX Generator

## Propósito

Generar presentaciones PowerPoint de calidad directiva (≥95/100 en rúbrica del usuario) a partir de:
- Notas manuscritas (vía OCR)
- Transcripción de reunión
- Spec / guion textual
- PPTX de referencia del cliente (para extraer paleta y estética)

**Caso canónico que la originó**: presentación Savia → acme-corp (mayo 2026), 11 slides, score objetivo 95+.

## Triggers

- "crear PPT/PPTX para [audiencia directiva/cliente/C-level]"
- "presentación para [SteerCo/comité/dirección/board]"
- Petición explícita: "genera la presentación de X para Y"

## Cuándo NO usar

- Slides de trabajo internas, daily, retro → usar templates simples.
- Documentos largos (>15 slides) → considerar Word/PDF.
- Outputs efímeros (no se proyectan a directivos).

---

## Pipeline (6 fases)

### F0 · Setup y assets

1. Crear carpeta de trabajo: `projects/{p}/meetings/{tema}/` o `output/pptx-{slug}/`.
2. Persistir `SPEC.md` y `CHECKPOINT.md` en disco (resiliencia entre sesiones).
3. Recolectar assets:
   - PPTX de referencia del cliente (si existe) → extraer `theme1.xml` con `zipfile`.
   - Logos cliente (SVG + PNG 400px).
   - Iconos Tabler en SVG + render PNG (navy + orange + white, 128px).
   - Imágenes stock (1600px) por slide narrativo.
4. Cargar palette + tipografía del cliente en `estetica-{cliente}.md`.

> Detalle: `references/assets-pipeline.md`

### F1 · Guion textual

1. Si hay notas manuscritas → OCR (Surya/TrOCR fallback) → `transcripcion.md`.
2. Extraer ángulos narrativos (5-8).
3. Mapear notas ↔ features del producto en `relaciones.md`.
4. Redactar `guion-ppt.md` con **una idea por slide** y titulares afirmativos.
5. Pedir aprobación humana del guion **antes** de renderizar.

> Detalle: `references/narrative-structure.md`

### F2 · Render PPTX (MCP `ppt_*`)

1. `ppt_create_presentation` con id estable (`{slug}-v1`).
2. Por cada slide: añadir shapes/imágenes vía MCP siguiendo el **patrón visual canónico** (ver F4).
3. `ppt_save_presentation` tras cada 2-3 slides (checkpointing).
4. Cada slide: ~12-18 llamadas MCP. Estimar antes.

> Detalle: `references/mcp-ppt-recipes.md`

### F3 · Autocrítica (Radical Honesty)

1. Renderizar a PNG (o leer XML con `zipfile`) y abrir visualmente.
2. Score por rúbrica (ver `references/scoring-rubric.md`).
3. Listado de findings priorizados (CRITICAL / HIGH / MEDIUM).
4. **Solo continuar si score ≥95/100** o usuario aprueba excepción.

### F4 · Iteración y pulido

- Aplicar findings priorizados.
- Re-score tras cada iteración.
- Mantener `CHECKPOINT.md` al día.

### F5 · Entrega

- PPTX final en ubicación N4/N4b (gitignored si contiene datos cliente).
- Resumen ejecutivo en chat: ruta, tamaño, score final.

---

## Patrón visual canónico

> Detalle completo: `references/visual-pattern.md`

### Dimensiones

- Slide: **10×7.5"** (4:3) por defecto. 13.33×7.5" (16:9) si plantilla cliente lo exige.
- Margen útil: 0.4-9.6" horizontal, 0.4-7.1" vertical.

### Tipografía

- Títulos: **Aptos Display 28pt navy bold** (fallback Calibri).
- Subtítulos: **15pt italic gris**.
- Body: **12-14pt** navy / gris oscuro.
- Cierre/callout: **15pt italic navy bold centrado**.

### Paleta canónica

> Detalle: `references/visual-pattern.md` (navy `#001C34`, naranja `#FF590D`, marfil `#FDEFEA`).

### Cajas y grids canónicos

> Detalle completo: `references/visual-pattern.md`

---

## Reglas inviolables (post-mortem caso acme-corp)

1. **Una idea por slide.** Si necesitas 2 ideas, son 2 slides.
2. **Titular afirmativo.** "X hace Y" — no "X" suelto, no preguntas.
3. **Cada slide tiene imagen O icono.** Slide solo-texto = bug.
4. **Cero frases marketing.** "Revolucionario", "líder", "best-in-class" → eliminar.
5. **Cero conteos del workspace** (commands/agents/skills) como KPIs en slides cliente.
6. **No usurpar marca del cliente.** Logo del cliente solo en posición esquina, nunca como logo principal.
7. **Score <95 → no entregar.** Iterar hasta umbral.
8. **Datos del cliente sin anonimizar** solo con confirmación explícita PM.
9. **Checkpoint cada 2-3 slides.** PPTX MCP se cuelga; perder trabajo es caro.
10. **Aprobación del guion antes de renderizar.** Re-renderizar 11 slides = 2-3 h.

---

## Errores conocidos y rúbrica

- Workarounds MCP / SVG / WSL → `references/known-issues.md`.
- Rúbrica de scoring (8 dimensiones, 100 pts, umbral 95) → `references/scoring-rubric.md`.

---

## Referencias

- `references/visual-pattern.md` — Anatomía detallada de cada layout
- `references/assets-pipeline.md` — Pipeline de extracción de paleta + iconos
- `references/mcp-ppt-recipes.md` — Recetas MCP slide por slide
- `references/narrative-structure.md` — Estructura narrativa pyramid
- `references/scoring-rubric.md` — Rúbrica de 8 dimensiones
- `references/known-issues.md` — Errores conocidos MCP + workarounds
- `references/checkpoint-template.md` — Plantilla `CHECKPOINT.md`

