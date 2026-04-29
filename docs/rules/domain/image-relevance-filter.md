# Image Relevance Filter — deterministic-first triage pre-Vision

> **SPEC**: SPEC-103 (`docs/propuestas/SPEC-103-deterministic-first-digests.md`)
> **Slice**: 1 (primitive only — heuristic + cache + log). Slice 2 (integración con `word-digest`, `pptx-digest`, `excel-digest`) follow-up.
> **Status**: canonical. Convierte la decisión "¿invocar Vision sobre esta imagen embebida?" de implícita en cada agent a explícita y cacheada por usuaria.

---

## Tesis (one paragraph)

Los agentes de digestión documental (`word-digest`, `pptx-digest`, `excel-digest`) extraen imágenes embebidas de docx / pptx / xlsx e invocan Claude Vision sobre **todas** ellas, incluso cuando son boilerplate corporativo (logos, iconos de header, banners divisores) que aparecen idénticos en cientos de documentos y no aportan información nueva. Cada llamada a Vision es coste, latencia y contaminación del output con descripciones irrelevantes ("logo de la empresa en esquina superior derecha"). El patrón opuesto — **deterministic-first, AI-fallback** — viene de `opendataloader-pdf`: usa heurísticas locales baratas para decidir, y solo invoca el modelo cuando la heurística no es concluyente. SPEC-103 generaliza ese patrón a imágenes embebidas en documentos no-PDF: cuatro reglas locales (cache hit, tamaño, dimensiones, aspect ratio) deciden la mayoría de los casos en O(ms) y per-user; Vision queda reservado para imágenes que **realmente** aportan info (gráficas, screenshots de UI, fotos de pizarra).

---

## Diseño

### 1. Subcomandos del CLI primitive

`scripts/image-relevance-filter.sh` expone tres subcomandos:

| Subcomando | Argumentos | Salida | Uso |
|---|---|---|---|
| `check` | `<image_path>` | exit 0 (skip) / 1 (invoke) + JSON | Decisión real-time: ¿invocar Vision? |
| `skip` | `<image_path>` | exit 0 + JSON | Mark explícito por la usuaria: "esta imagen es boilerplate, no la mires nunca más" |
| `log` | `<image_path> <skip\|invoke>` | exit 0 + JSON | Auditoría + auto-promote: 3 marks de `skip` para el mismo sha → auto-añade a skip-list |

### 2. Heurística (orden de evaluación)

```
1. Cache hit on skip-list                → SKIP (cache)
2. File size < 10 KB                     → SKIP (probable icon)
3. Pixel dimensions < 50x50              → SKIP (probable icon, requires `identify`)
4. Aspect ratio ≥ 8:1 OR ≤ 1:8           → SKIP (probable banner/divider)
5. Otherwise                             → INVOKE (Vision warranted)
```

Decisiones de diseño:

- **First-match-wins**: cuanto más rápida sea la regla, más arriba. Cache hit es O(grep skip-list) — instantáneo.
- **`identify` opcional**: si ImageMagick no está instalado, las reglas 3 y 4 se saltan (degradación graceful). El filtro sigue funcionando con cache + size.
- **Thresholds duros, no configurables vía flag**: defaults conservadores (10 KB, 50 px, 8:1). Para tunear, edit del script — la API limpia se mantiene.
- **Aspect ratio bidireccional**: `≥ 8:1` o `≤ 1:8` (banner horizontal o vertical).

### 3. Cache layout (off-repo, per-user)

```
~/.savia/digest-cache/images/
├── skip-list.txt       # sha256 hex per line, known-irrelevant
└── last-seen.jsonl     # JSONL audit trail of every decision
```

- Override via env `SAVIA_DIGEST_CACHE_DIR` (útil para testing aislado).
- Append-only: el log nunca se sobrescribe (auditable).
- Skip-list deduplicada en escritura (evita filas duplicadas si la misma sha se añade dos veces).

### 4. Auto-promote rule

Cuando `log <image> skip` se invoca y el sha ya tiene **≥ 3** entries previas con `decision: skip`, el sha se añade automáticamente al `skip-list.txt`. Esto convierte uso real en heurística refinada sin intervención manual.

Diseñado para que **3 documentos diferentes** con la misma imagen marcada como skip → auto-aprende. No para que la misma imagen en el mismo documento se cuente 3 veces (eso sería ruido).

### 5. JSON output format

Cada subcomando emite a stdout una línea JSON:

```json
{"action":"skip","reason":"size-below-threshold","sha":"abc...","size":4096,"dims":"32x32"}
{"action":"invoke","reason":"default-pass","sha":"def...","size":48000,"dims":"800x600"}
{"action":"skip","reason":"auto-promoted-after-3-marks","sha":"...","size":0,"dims":""}
```

Razones documentadas:
- `cache-hit` — sha ya en skip-list
- `size-below-threshold` — file ≤ 10 KB
- `dimensions-below-threshold` — ambos lados ≤ 50 px
- `aspect-ratio-extreme` — banner/divider detectado
- `default-pass` — no match con ninguna regla skip
- `manual-add` — `skip` subcommand explícito
- `auto-promoted-after-3-marks` — el log triggea promoción automática
- `logged` — solo registro, sin promoción

### 6. Cómo lo consumen los agents (Slice 2 follow-up)

Cuando se integre en `word-digest` / `pptx-digest` / `excel-digest`:

```python
# Pseudocode within the agent
for img in extracted_images:
    rc = subprocess.run(
        ["bash", "scripts/image-relevance-filter.sh", "check", img.path]
    ).returncode
    if rc == 0:
        # SKIP — don't invoke Vision, log decision for refinement
        subprocess.run(["bash", "scripts/image-relevance-filter.sh", "log", img.path, "skip"])
        continue
    # INVOKE Vision
    description = vision_describe(img)
    subprocess.run(["bash", "scripts/image-relevance-filter.sh", "log", img.path, "invoke"])
```

Los agents NO se modifican en este Slice. La primitiva está disponible para integración cuando la usuaria de greenlight (cambia behavior de 3 agents existentes — riesgo medio, requiere validación visible).

---

## Atribución

Patrón fuente: `opendataloader-pdf` modo híbrido (local-first / AI-fallback). Re-implementación en bash + sha256 + heurísticas mínimas, sin importar código del proyecto fuente. La novedad aquí es el auto-promote rule y la separación strict subcommand-per-action.

---

## Cross-refs

- **SPEC-103** — spec original (`docs/propuestas/SPEC-103-deterministic-first-digests.md`)
- **SPEC-102** — opendataloader-pdf migration (relacionado, separate scope)
- **`.claude/agents/word-digest.md`** — consumidor Slice 2
- **`.claude/agents/pptx-digest.md`** — consumidor Slice 2
- **`.claude/agents/excel-digest.md`** — consumidor Slice 2

---

## No hace (esta Slice)

- NO modifica los agents `word-digest`, `pptx-digest`, `excel-digest` (Slice 2 follow-up).
- NO añade ML model — heurísticas simples bastan (per spec out-of-scope).
- NO cubre PDF (SPEC-102 hace ese trabajo con opendataloader-pdf).
- NO cachea entre usuarios — cada usuaria tiene su `~/.savia/digest-cache/`.
- NO bloquea Vision si la heurística falla — graceful degradation: si `identify` no está, reglas 3+4 se saltan; si el cache no se puede crear, exit 4.
