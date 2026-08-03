# Spec: SE-299 — Model Tier Optimization for Extraction Agents

**Task ID:**        SE-299
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-03
**Creado por:**     Savia

**Developer Type:** agent-single
**Estado:**         PROPOSED

---

## 1. Contexto y Objetivo

Savia usa tiers de modelo (heavy/mid/fast) resueltos en runtime desde
`~/.savia/preferences.yaml` via el plugin `SaviaFoundationPlugin`. El mapeo
actual: heavy/mid → deepseek-v4-pro, fast → deepseek-v4-flash.

Varios agentes de extraccion (digest) y navegacion estan configurados en
heavy/mid cuando su trabajo es en gran parte mecanico (extraccion de texto,
markitdown, OCR, fetch). No requieren razonamiento profundo.

Objetivo: asignar el tier correcto por agente segun si la tarea requiere
interpretacion semantica (mantener heavy/mid) o es extraccion mecanica (flash).

## 2. Criterio de clasificacion

| Tipo de trabajo | Tier | Ejemplos |
|---|---|---|
| Interpretacion semantica (ambiguedad, reglas de negocio) | heavy/mid | pdf-digest, excel-digest |
| Extraccion + contexto ligero | mid | word-digest, pptx-digest, visual-digest |
| Extraccion mecanica (markitdown, OCR, fetch, clone) | fast | archive-digest, web-research |

## 3. Cambios propuestos

| Agente | Tier actual | Tier nuevo | Razon |
|---|---|---|---|
| archive-digest | mid | **fast** | markitdown mecanico, sin interpretacion |
| web-research (skill) | orquestador (flash) | sin cambio | ya usa flash de facto via skill |
| word-digest | heavy | **mid** | extraccion de actas/manuales con contexto ligero |
| pptx-digest | heavy | **mid** | extraccion de notas/imagenes/datos |
| visual-digest | heavy | **mid** | OCR contextual, interpretacion ligera |
| pdf-digest | heavy | heavy | resolver ambiguedades de negocio |
| excel-digest | heavy | heavy | extraer reglas de negocio de spreadsheets |
| meeting-digest | mid | mid | extraer info de negocio de reuniones |

## 4. Criterios de Aceptacion

- [ ] AC1: archive-digest pasa a fast
- [x] AC2: web-research es skill, ya usa tier del orquestador (flash)
- [ ] AC3: word-digest, pptx-digest, visual-digest pasan a mid
- [ ] AC4: pdf-digest, excel-digest, meeting-digest sin cambio
- [ ] AC5: El plugin SaviaFoundationPlugin resuelve los nuevos tiers correctamente
- [ ] AC6: tests de catalogo de agentes siguen pasando (AGENTS.md sync)

## 5. Estado de Implementacion

| Slice | Estado |
|---|---|
| S1: archive-digest → fast | COMPLETADO |
| S2: word-digest, pptx-digest, visual-digest → mid | COMPLETADO |
| S3: web-research (skill) → flash de facto | VERIFICADO (sin cambio necesario) |
| S4: Catalogos regenerados | COMPLETADO |
| S5: Drift check | PASS |
