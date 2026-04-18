---
id: SE-036
title: Specs frontmatter migration — 111 specs sin YAML frontmatter a formato canónico
status: PROPOSED
origin: ROADMAP-UNIFIED-20260418 Wave 4 D1 follow-up + scripts/spec-status-normalize.sh audit (111 specs detected)
author: Savia
related: scripts/spec-status-normalize.sh, SPEC-120-spec-kit-alignment
approved_at: null
applied_at: null
expires: "2026-06-18"
---

# SE-036 — Specs frontmatter migration

## Purpose

Si NO hacemos esto: 111 de 156 specs NO tienen YAML frontmatter (usan `> Status: DRAFT` en prosa). Consecuencias reales:
- Cualquier tooling grep/jq-based falla silenciosamente en esos 111 (están invisibles)
- `spec-status-normalize.sh --apply` no puede tocarlos (safety-first)
- No podemos ejecutar queries como "¿qué specs PROPOSED tengo?" con garantía de completitud
- Alignment con github/spec-kit (SPEC-120) exige frontmatter — bloqueamos esa alineación mientras persista el gap

Cost of inaction: cada semana que pasa, más specs se añaden al bote de 111 porque no hay enforcement. El gap crece. Sin frontmatter, las ~73 specs que `--suggest` marca como Implemented están mintiendo silenciosamente (creemos que están proposed cuando ya están merged).

## Objective

**Único y medible**: migrar los 111 specs sin YAML frontmatter a formato canónico (frontmatter con id/title/status mínimo), validado por `spec-status-normalize.sh --audit` → missing=0. Criterio adicional: los ~73 specs que `--suggest` marca como Implemented deben confirmar status manualmente contra CHANGELOG antes de aplicar.

NO es: cambiar el contenido de las specs. SOLO: añadir frontmatter YAML + normalizar `status:` a valor canónico.

## Slicing

### Slice 1 — Batch Implemented confirmados (30 specs, 2h)

Los specs con CHANGELOG reference clara (grep directo al ID encuentra la version merged):
- Migrar frontmatter con `status: Implemented` + `applied_at: <fecha del CHANGELOG>`
- Validación: cada spec debe aparecer en CHANGELOG con versión y commit hash

### Slice 2 — Batch UNLABELED review humano (40 specs, 3h)

Los que `--suggest` marca UNLABELED — requieren decisión humana:
- Proposed (aún vigente)
- DROPPED (obsoleto, superseded)
- Implemented parcialmente (ej. Phase 1 done, Phase 2 pending)

Slice escribe un `output/se-036-review-batch-{date}.md` con propuestas por spec; Mónica valida en batch; Savia aplica en masa.

### Slice 3 — Batch Proposed vigente (41 specs, 1h)

Los que aún son vigentes PROPOSED — migración mecánica:
- Añadir frontmatter con `status: PROPOSED`
- Preservar cualquier metadata del body (author, date, priority)

### Slice 4 — Gate de enforcement (30min)

Añadir a `scripts/ci-extended-checks.sh` check #8: "todos los specs en docs/propuestas/**.md tienen frontmatter YAML con `status:` canónico". Fail fast si alguien añade spec sin frontmatter.

## Acceptance Criteria

- [ ] AC-01 `spec-status-normalize.sh --audit` reporta missing=0
- [ ] AC-02 Los 30 Implemented confirmados tienen `applied_at` + CHANGELOG ref verificada
- [ ] AC-03 Los 40 UNLABELED tienen decision humana documentada en el review doc
- [ ] AC-04 Los 41 Proposed vigentes tienen `expires:` si son Wave 1/2 del ROADMAP
- [ ] AC-05 ci-extended-checks.sh check #8 instalado y verde
- [ ] AC-06 Tests bats que verifican que ningún spec sin frontmatter queda en docs/propuestas/

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Marcar spec como Implemented sin estarlo | Gate humano en Slice 2 — no auto-apply |
| Frontmatter rompe renderizado GitHub | Validar con jekyll-style dry-render en Slice 4 |
| 156 specs crece antes de terminar (race) | Enforcement check #8 en Slice 4 evita regresión |

## Aplicación Spec Ops

- **Simplicity**: un objetivo (missing=0) medible
- **Purpose**: cost of inaction cuantificado (73 specs mintiendo)
- **Speed**: 4 slices, 3 de ellos <3h cada uno
- **Theory of Relative Superiority**: expires 2026-06-18, si no se hace re-review

## Referencias

- `scripts/spec-status-normalize.sh`: tool que detecta el gap
- `output/spec-status-report-20260418.md`: reporte inicial
- ROADMAP-UNIFIED-20260418 §Wave 4 D1
- SPEC-120 spec-kit alignment: exige frontmatter canónico

## Dependencia

Independiente. Puede iterar en paralelo con SE-032/033/034.
