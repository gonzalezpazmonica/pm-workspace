---
id: SE-172
title: SE-172 — markitdown como capa 0 universal de digestión
status: APPROVED
origin: microsoft/markitdown (MIT, 143k★, v0.1.6 2026-05-26) — análisis 2026-06-03
author: Savia
priority: media
effort: M 6h
related: SPEC pdf-digest, word-digest, excel-digest, pptx-digest, visual-digest, meeting-digest
proposed_at: "2026-06-03"
applied_at: null
expires: "2026-09-03"
era: 199
---

# SE-172 — markitdown como capa 0 universal de digestión

## Why

pm-workspace tiene 6 digest-agents (`pdf-digest`, `word-digest`, `excel-digest`, `pptx-digest`, `visual-digest`, `meeting-digest`). Cada uno reimplementa parsing+normalización (extracción de texto, tablas, imágenes, OCR, transcripción) **antes** de su pipeline de 4 fases de análisis de dominio. Resultado: ~6 superficies de seguridad I/O, código duplicado de extracción, formatos de entrada limitados a lo que cada agente sabe parsear.

Microsoft markitdown (MIT, 143k★) es una utility Python que convierte ficheros heterogéneos a Markdown optimizado para LLMs. Cobertura: PDF, DOCX, PPTX, XLSX, imágenes (EXIF+OCR), audio (transcripción), HTML, CSV/JSON/XML, ZIP, YouTube, EPub, Outlook .msg. Token-efficient. API estable.

Lección que pm-workspace puede importar: **separar extracción (commodity) de análisis de dominio (valor)**. Los digest-agents deberían recibir Markdown ya canónico y centrarse en cross-ref con perfiles, contexto de proyecto, riesgos y reglas — no en luchar con `python-pptx` o `openpyxl`.

Coste de no adoptar: cada formato nuevo (Outlook .msg, EPub, ZIP, YouTube) requiere escribir un parser propio. Cada digest-agent mantiene código de extracción que duplica el de otros. Coste de adoptar: ~6h para wrappear markitdown como capa 0 + adaptar los 6 agentes a consumir Markdown canónico.

## Scope (M 6h, 3 slices)

### Slice 1 (S 1h) — Wrapper `scripts/digest-extract.sh`

Script único que delega en markitdown:

```bash
bash scripts/digest-extract.sh <input-file> [--output <md-file>]
# Auto-detecta formato. Salida: Markdown canónico + YAML front-matter
# con metadatos (mime, páginas, idioma detectado, hash del original)
```

Instalación opt-in: `pip install 'markitdown[pdf,docx,pptx,xlsx]'` (solo extras necesarios, no `[all]`).

### Slice 2 (S 3h) — Adaptar digest-agents

Cada uno de los 6 agentes (`pdf-digest`, `word-digest`, `excel-digest`, `pptx-digest`, `visual-digest`, `meeting-digest`) modifica su Fase 1 (extracción) para invocar `digest-extract.sh` en lugar de su parser propio. Las Fases 2-4 (estructura, contexto, reglas) consumen el Markdown canónico sin cambios.

Compatibilidad: si markitdown falla, fallback al parser histórico del agente (ya existente). Zero migración obligatoria.

### Slice 3 (S 2h) — Cobertura nueva gratis

Activar 4 nuevos formatos con un agente único `archive-digest` que delega todo en markitdown:

- ZIP (itera contenidos)
- EPub
- YouTube URL (transcripción)
- Outlook .msg

Sin pipelines de 4 fases — solo extracción + indexación en memoria.

## Acceptance Criteria

- **AC-01**: `scripts/digest-extract.sh foo.pdf` produce Markdown válido con front-matter (mime, hash, timestamp).
- **AC-02**: Los 6 digest-agents existentes pasan sus tests actuales sin cambios funcionales (mismo análisis de dominio sobre Markdown equivalente).
- **AC-03**: ≥4 formatos nuevos cubiertos (ZIP, EPub, YouTube, .msg) sin escribir parser propio.
- **AC-04**: Reducción ≥40% de LOC en parsers de los 6 digest-agents (medido sobre `scripts/*-digest-*.py`).
- **AC-05**: Sanitización de inputs: usar `convert_local()` por defecto (no `convert()` permisivo). Rechazar URIs no-file en agentes locales.
- **AC-06**: Cuando markitdown falla, fallback al parser histórico del agente con warning en log (zero data loss).
- **AC-07**: Gate de seguridad — `digest-extract.sh` ejecuta con `umask 077` y rechaza paths fuera de `$WORKSPACE_ROOT` salvo flag explícito `--external`.
- **AC-08**: Tests BATS ≥20 cubriendo: cada formato soportado, fallback, sanitización, front-matter, rechazo de paths externos.

## Risks

- **Deps Python**: `markitdown[all]` instala muchas libs (poppler, pandoc, ffmpeg). Mitigación: extras selectivos (`[pdf,docx,pptx,xlsx]` cubre el 90% de casos).
- **Privilegios I/O**: markitdown opera con privilegios del proceso (igual que `open()`). Mitigación: AC-05 + AC-07 restringen superficie.
- **Calidad subjetiva**: algunos formatos (PDF escaneados complejos) pueden dar Markdown peor que el parser histórico. Mitigación: fallback en AC-06 + opt-in por agente vía flag `MARKITDOWN_ENABLED=true`.
- **Versioning**: markitdown v0.x.x — API puede cambiar. Mitigación: pin estricto en requirements.txt + test de regresión por release.

## Out of Scope

- Azure Document Intelligence / Content Understanding (cloud paid). Feature opt-in para fase 2 si surge necesidad real.
- Plugin `markitdown-ocr` (LLM Vision OCR). Evaluar tras Slice 2 si se detecta gap real.
- Refactor de `meeting-digest` para usar markitdown audio transcription en lugar de pipeline propio (alto riesgo, baja prioridad).

## Dependencies

- Python ≥3.10 (ya cubierto en pm-workspace).
- Skills `*-digest` actuales operativos como baseline.
- `confidentiality-gate` cubre el sandboxing de inputs.

## References

- https://github.com/microsoft/markitdown — repo upstream
- https://pypi.org/project/markitdown/ — paquete PyPI
- License: MIT — compatible con pm-workspace
