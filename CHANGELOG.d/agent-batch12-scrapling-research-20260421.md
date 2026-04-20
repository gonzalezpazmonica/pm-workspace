# Batch 12 — Era 183 Scrapling research reprioritization

**Date:** 2026-04-21
**Branch:** `agent/batch12-scrapling-research-reprioritization-20260421`
**Version bump:** 5.60.0

## Summary

Research de `D4Vinci/Scrapling` (BSD-3, 38K★, Python) identifica un champion Tier 3 con ROI inmediato: desbloquea `tech-research-agent` + skill `web-research` en sites Cloudflare/DataDome-gated que hoy fallan silenciosamente.

## Added

- `docs/propuestas/SE-061-scrapling-research-backend.md` — 4 slices (21h total):
  - Slice 1 (S, 4h): `scripts/scrapling-probe.sh` — viability check
  - Slice 2 (M, 8h): `scripts/scrapling-fetch.sh` — wrapper con fallback a curl
  - Slice 3 (M, 6h): integración en `tech-research-agent` + `web-research` skill
  - Slice 4 (S, 3h): MCP server opt-in registration

## Changed

- `docs/ROADMAP.md` — Era 183 añadida. Tier 3 Champions reordenado por ROI research-stack:
  1. **SE-061 Scrapling** (nuevo champion #1 — desbloquea agents activos)
  2. SE-035 Mutation testing (probe merged)
  3. SE-032 Reranker (probe merged)
  4. SE-033 BERTopic (probe merged)
  5. SE-028 Oumi (probe in-flight)
  6. SE-041 Memvid (probe in-flight)

## Rationale

SE-061 es el único champion Tier 3 con caso de uso activo hoy: cada invocación de `tech-research-agent` sobre Cloudflare-gated sites falla silenciosamente, produciendo research incompleta sin señal de error. Los demás Tier 3 son probes cuyos consumidores (training pipeline, clustering) aún no empujan.

## Compliance

- BSD-3 compatible — pendiente actualización `docs/decision-log.md` en Slice 1
- Opt-in only — fallback a curl/WebFetch preserva zero-install path
- Rule #8: spec PROPOSED, requiere aprobación humana antes de implementación

## Referencias

- Research report: `output/research/scrapling-20260421.md` (local only, output/ gitignored)
- Audit anterior: `output/audit-roadmap-reprioritization-20260420.md`
- SE-056 Python SBOM — añadir `scrapling` dep si se adopta
- SE-058 MCP audit — valida entry en Slice 4
