---
spec_id: SPEC-102
title: Migrate pdf-digest to opendataloader-pdf (deterministic-first + bounding boxes)
status: PROPOSED
origin: opendataloader-pdf analysis (2026-04-15)
severity: Alta
effort: ~12h
priority: baja
---

# SPEC-102: pdf-digest on opendataloader-pdf

## Problema

`pdf-digest` hoy usa PyMuPDF + Claude Vision. Dos fallos estructurales:

1. **Accuracy baja** — pymupdf4llm puntúa 0.732 en benchmark; opendataloader-pdf
   0.907. Diferencia se nota en PDFs multi-columna, tablas complejas,
   formulas, scans.
2. **Coste alto** — invocamos Vision en cada página. Proyectos con 100+
   PDFs queman presupuesto API.

Además: no tenemos bounding boxes, así que las citas en `source-tracking.md`
solo llegan a nivel fichero, no a nivel región. `spec-verify` y
`meeting-digest` pierden trazabilidad fina.

## Solucion

Migrar `pdf-digest` a [opendataloader-pdf](https://github.com/opendataloader-project/opendataloader-pdf)
(Apache 2.0, 17k★, PDF Association + veraPDF):

1. **Modo local determinista** (0.015s/página) como default
2. **Modo híbrido** solo en páginas que el determinista marca de baja confianza
3. **Bounding boxes** para cada elemento → citas con coordenadas
4. **Prompt injection filter** built-in → Savia Shield Capa 1.5
5. **Reading order XY-Cut++** correcto en multi-columna

Wrapper Python sobre JAR de opendataloader (como hace su SDK oficial).
Fallback a PyMuPDF si Java no está disponible (degradación controlada).

## Arquitectura

```
pdf-digest agent
    ↓
scripts/pdf-extract.sh [--engine opendataloader|pymupdf|auto]
    ↓
    ├── opendataloader: Java JAR + Python wrapper (default)
    │   output: JSON con elementos + bounding boxes + reading order
    ├── pymupdf (fallback si no hay Java)
    │   output: texto plano + Vision para páginas complejas
    └── auto: detecta Java → elige opendataloader
```

## Flujo nuevo de pdf-digest (4 fases revisadas)

- **Fase 1 — Extracción local**: opendataloader hybrid mode. Output JSON con
  elementos tipados (heading, paragraph, table, figure) + bounding boxes.
- **Fase 2 — Prompt injection scan**: verificar texto invisible + prompts
  ocultos. Si detectado → flag N4 + abortar pipeline, NO pasar a agentes.
- **Fase 3 — Contexto proyecto**: carga glossary, stakeholders, phonetic-map
  como hoy.
- **Fase 4 — Síntesis con citas bounding-box**: el agente digest cita
  `[pdf:file.pdf:p.3:box=(120,340,480,420)]` para cada hallazgo.

## Citas bounding-box en source-tracking.md

Extender `docs/rules/domain/source-tracking.md`:

```
@pdf:{path}[:p.N][:box=(x1,y1,x2,y2)]

Ejemplos:
- @pdf:informe-sala.pdf:p.3:box=(120,340,480,420)  — región concreta
- @pdf:informe-sala.pdf:p.3                          — página entera
- @pdf:informe-sala.pdf                              — fichero entero
```

## Integracion con Savia Shield

Añadir **Capa 1.5** (entre Capa 1 regex y Capa 2 Ollama):

```
data-sovereignty-gate.sh
    ↓
Capa 1 (regex) — PII known, creds
    ↓
Capa 1.5 (NEW) — prompt injection scan en PDFs ingeridos (opendataloader filter)
    ↓
Capa 2 (Ollama) — clasificación local CONFIDENTIAL/PUBLIC/AMBIGUOUS
    ↓
Capa 3 (audit post-escritura)
```

## Criterios de aceptacion

- [ ] `scripts/pdf-extract.sh` wrapper Python sobre opendataloader JAR
- [ ] Fallback a PyMuPDF si `java -version` falla
- [ ] Flag `--engine {opendataloader|pymupdf|auto}` (default auto)
- [ ] Output JSON con elementos tipados + bounding boxes
- [ ] `pdf-digest` agent actualizado para citar bbox cuando disponible
- [ ] `source-tracking.md` documenta sintaxis `@pdf:...:p.N:box=(...)`
- [ ] Nueva fase Capa 1.5 prompt injection scan
- [ ] Tests BATS >= 15 casos (incluye degradación sin Java)
- [ ] Documentación de migración para proyectos con pdf-digest activo

## Restricciones

- **PDF-EXT-01**: Java 11+ es dependencia OPCIONAL; fallback debe funcionar
- **PDF-EXT-02**: Output determinista byte-by-byte entre runs (mismo input → mismo JSON)
- **PDF-EXT-03**: Bounding boxes en coordenadas PDF (points, no pixels)
- **PDF-EXT-04**: Prompt injection detectado → abort pipeline + log N4
- **PDF-EXT-05**: Cache de extracción por SHA-256 del PDF (idempotencia con digest-traceability)

## Benchmarks objetivo

| Métrica | PyMuPDF actual | opendataloader target |
|---------|----------------|---------------------|
| Accuracy overall | ~0.73 | ≥0.90 |
| Table extraction | ~0.40 | ≥0.90 |
| Coste API por 100 págs | ~$0.50 Vision | ~$0.05 híbrido |
| Latencia 100 págs | ~5 min | ~1.5 s local + AI solo complejas |

## Out of scope

- Tagged PDF output (SPEC-104)
- Migración de word/pptx/excel digests (SPEC-103)
- UI web para preview de bounding boxes

## Referencias

- [opendataloader-pdf](https://github.com/opendataloader-project/opendataloader-pdf)
- [Benchmarks](https://opendataloader.org/docs/benchmarks)
- `.opencode/agents/pdf-digest.md` (agente actual)
- `docs/rules/domain/source-tracking.md` (citas)
- `docs/rules/domain/data-sovereignty.md` (Savia Shield)
- `docs/rules/domain/digest-traceability.md` (idempotencia)
