---
version_bump: minor
section: Added
---

## [6.13.0] — 2026-04-27

Batch 74 — Era 190 APPROVED. 7 specs nuevos (SE-081..SE-087) origen análisis de `mattpocock/skills` (MIT, 26.4k⭐); Critical Path Q2-Q3 reprioritizado por relevancia / urgencia / dependencias.

### Added

- `docs/propuestas/SE-081-pocock-skills-quick-wins.md` — APPROVED priority alta (S 2h). Tres skills MIT clean-room: `caveman` (modo ultra-comprimido -75% tokens), `zoom-out` (mapa de módulos), `grill-me` (interrogatorio relentless aligned con Rule #24 radical-honesty). Zero código, sólo markdown + atribución.
- `docs/propuestas/SE-082-architectural-vocabulary-discipline.md` — APPROVED priority alta (M 4h). Vocabulario obligatorio Module/Interface/Seam/Adapter/Depth/Locality para `architect` y `architecture-judge`. Extiende SE-080 attention-anchor. Auditor warning-only en este Slice; gate enforced en SE-084.
- `docs/propuestas/SE-083-tdd-vertical-slice-skill.md` — APPROVED priority media (S 2h). Skill que codifica el anti-pattern de horizontal slicing. Cross-reference desde `test-architect`.
- `docs/propuestas/SE-084-skill-catalog-quality-audit.md` — APPROVED priority alta (M 6h, 2 slices). Auditor estático (Use-when triggers + ≤100 LOC + frontmatter validation) + pr-plan G14 gate sólo sobre skills modificados en el PR. Baseline ratchet via `baseline-tighten.sh`.
- `docs/propuestas/SE-085-write-a-skill-meta.md` — APPROVED priority baja (S 2h). Meta-skill consultivo para crear skills nuevos. Depende de SE-084 (regla canónica enforced).
- `docs/propuestas/SE-086-ubiquitous-language-extractor.md` — APPROVED priority media (M 5h, 2 slices). Skill DDD glossary + extractor python que cruza `.memory-store.jsonl` con `CONTEXT.md` per-proyecto, marca términos new/existing/inconsistent. Edge `DOMAIN_TERM` en grafo episodic (extiende SE-076 Slice 1).
- `docs/propuestas/SE-087-design-an-interface-parallel.md` — APPROVED priority media (M 4h). Skill que spawnea N=3 sub-agentes paralelos con prompts ortogonales (minimalist / compositional / type-safe / pure functional) para destapar trade-offs en diseño de interfaz. Reusa Agent tool existente; opt-in delegate a SE-074 parallel-specs-orchestrator para problemas grandes.

### Changed

- `docs/ROADMAP.md` — header línea 3 actualizada con Era 190 APPROVED. Critical Path Q2-Q3 reprioritizado: 12 items unificados por relevancia (compliance enterprise + skill catalog quality multipliers + sovereignty residual + apalancamiento residual). Sinergias documentadas extendidas con cross-refs SE-082/084/086/087 y SPEC-SE-036/037.

### Re-implementation attribution

- `mattpocock/skills` (MIT, jamiepine/voicebox-style clean-room): patterns extraídos para SE-081 (caveman/zoom-out/grill-me skills), SE-082 (LANGUAGE.md vocabulary), SE-083 (tdd/SKILL.md anti-pattern), SE-084 (write-a-skill meta-discipline), SE-085 (write-a-skill skill), SE-086 (ubiquitous-language + domain-model skills), SE-087 (design-an-interface skill). Zero código copiado; cada spec cita upstream commit hash en header.

### Reprioritization rationale (Critical Path)

Cinco ejes documentados:
1. **Compliance enterprise (P1)** — SPEC-SE-036 JWT mint + SPEC-SE-037 audit JSONB son hard-gates para Savia Enterprise sales (ISO-42001/EU AI Act/GDPR evidence). Items #6-7.
2. **Skill catalog quality (multiplicador)** — Era 190 baja el "tax" recurrente de cada skill nuevo. SE-081 (S 2h zero deps) abre como warm-up. SE-084 Slice 1 establece baseline antes de Era 190 grow.
3. **Sovereignty residual** — SE-077/078/079/080 IMPLEMENTED batch 70-73; quedan E2E validations pendientes de boot por la usuaria.
4. **Apalancamiento residual** — SE-074/075/076 IMPLEMENTED batches 63-73 (Era 188 cerrando con #717).
5. **Ratio rápido / habilitador** — SE-081 abre Era 190 (zero deps, S 2h) — exactamente el rol que SE-073 cumplió en Era 188.

Pipeline final 12 items, ~58h efectivos (~3 days reales con paralelismo activo).

### Spec ref

Era 190 (`docs/ROADMAP.md` sección Era 190) → APPROVED 2026-04-27. Origen: análisis de `mattpocock/skills` documentado en CHANGELOG; cierre cuando SE-081, SE-082, SE-083, SE-084, SE-086 estén IMPLEMENTED. SE-085 y SE-087 son P3 (cierre opcional).
