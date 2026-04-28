---
version_bump: minor
section: Added
---

## [6.22.0] — 2026-04-29

Batch 82 — SPEC-103 Slice 1 IMPLEMENTED. Image relevance filter primitive: heurística deterministic-first (cache + tamaño + dimensiones + aspect ratio) que decide pre-Vision si una imagen embebida en docx/pptx/xlsx merece llamada al modelo. Patrón opendataloader-pdf (local-first / AI-fallback) generalizado a imágenes. Slice 2 (integración en `word-digest`/`pptx-digest`/`excel-digest`) follow-up — modifica behavior de 3 agents existentes, requiere greenlight explícito.

### Added

#### Primitive

- `scripts/image-relevance-filter.sh` — CLI bash con 3 subcomandos:
  - `check <image>` — exit 0 (skip) / 1 (invoke Vision) + JSON con `action`, `reason`, `sha`, `size`, `dims`
  - `skip <image>` — añade sha al `skip-list.txt` (manual mark)
  - `log <image> <skip|invoke>` — append a JSONL audit trail; auto-promote a skip-list tras ≥3 marks de `skip`
  - 4 reglas heurísticas evaluadas en orden (first-match-wins): cache hit → file size <10 KB → dimensions <50px → aspect ratio ≥8:1 (banner)
  - Cache off-repo per-user en `~/.savia/digest-cache/images/` (override via `SAVIA_DIGEST_CACHE_DIR`)
  - 5 exit codes documentados: 0 skip / 1 invoke / 2 usage / 3 file missing / 4 cache write fail
  - Graceful degradation: si `identify` (ImageMagick) no está, reglas 3+4 se saltan; cache + size siguen funcionando

#### Canonical rule

- `docs/rules/domain/image-relevance-filter.md` — define el modelo:
  - Tesis: Vision-on-everything contamina output con descripciones de boilerplate; deterministic-first triage atrapa logos/iconos/banners en O(ms)
  - 4 heurísticas en orden con justificación per-regla
  - JSON output format con razones documentadas (cache-hit, size-below-threshold, dimensions-below-threshold, aspect-ratio-extreme, default-pass, manual-add, auto-promoted-after-3-marks, logged)
  - Pseudocode de cómo los 3 agents lo consumirán en Slice 2
  - Cross-refs SPEC-102 (PDF migration relacionado), SPEC-103 (origen)

#### Tests

- `tests/structure/test-image-relevance-filter.bats` — 33 tests certified. Cubre file safety×3, spec ref×2, usage/negative×6, heuristic positive×7 (incluye auto-promote ≥3 + boundary 2-marks-not-enough), edge×5 (cache idempotencia, JSON sha 64-char, zero-byte), rule doc structure×6, spec ref + exit codes×3, graceful degradation×1.

### Re-implementation attribution

`opendataloader-pdf` modo híbrido (local-first / AI-fallback) — patrón fuente. Clean-room re-implementación en bash + sha256 + heurísticas explícitas; sin importar código del proyecto fuente. Aporte propio: la auto-promote rule (≥3 marks → skip-list) y la separación strict subcommand-per-action.

### Acceptance criteria

#### SPEC-103 Slice 1 (4/6 + 2 deferred a Slice 2)

- ✅ AC-01 `scripts/image-relevance-filter.sh` con check/skip/log subcomandos
- ✅ AC-02 Heurísticas de tamaño, aspect ratio, cache de checksums (4 reglas en orden)
- 〰 AC-03 `word-digest`, `pptx-digest`, `excel-digest` consultan filtro antes de Vision — **DEFERRED** Slice 2 (modifica 3 agents existentes, requiere greenlight)
- ✅ AC-04 Log de decisiones en cache (refinamiento automático via auto-promote ≥3 marks)
- ✅ AC-05 Tests BATS ≥12 — cumplido (33 tests certified)
- 〰 AC-06 Reducción medible 40% Vision — **DEFERRED** medible solo tras Slice 2 integration en producción

### Hard safety boundaries (autonomous-safety.md)

- `set -uo pipefail` en `image-relevance-filter.sh`.
- Cache off-repo en `~/.savia/digest-cache/` — nunca toca el repo.
- NO modifica agents existentes en este Slice (riesgo cero sobre flow actual).
- Skip-list idempotente (escribir mismo sha 2× no duplica fila).
- Cero red, cero git operations.
- Cumple `docs/rules/domain/autonomous-safety.md`: rama `agent/spec-103-...`, sin push automático ni merge.

### Spec ref

SPEC-103 (`docs/propuestas/SPEC-103-deterministic-first-digests.md`) → Slice 1 IMPLEMENTED 2026-04-29. Slice 2 (integración en 3 agents) follow-up con greenlight explícito por modificación de behavior de agents existentes. Era 232 cerrada (SE-035+036+037 + SPEC-125 PROPOSED). Critical Path libre — siguiente prioridad humana.
