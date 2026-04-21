# Batch 15 — SE-061 Slice 2 Scrapling fetch wrapper

**Date:** 2026-04-21
**Branch:** `agent/batch15-scrapling-slice2-20260421`
**Version bump:** 5.63.0

## Summary

Segundo slice SE-061. Wrapper estable sobre Scrapling (parser-only, sin Chromium requerido) con fallback automático a curl cuando Scrapling no está disponible. Interface uniforme para Slice 3 (integración con agentes de research).

## Added

- `scripts/scrapling-fetch.sh`:
  - Detección de backend: `scrapling` si instalado, si no `curl`
  - Flags: `--selector CSS`, `--json`, `--stealth`, `--timeout SEC`
  - Extrae: título, HTTP status, URL final (post-redirect), texto
  - Fallback gracioso: curl con user-agent `SaviaResearch/1.0`
  - Exit codes: 0 (OK), 1 (fetch error), 2 (usage error)
  - Sólo egress a URL del usuario, zero side-channels

- `tests/test-scrapling-fetch.bats`:
  - 29 tests cubriendo help, URL validation, flag parsing, backend detection, error paths, isolation, coverage
  - Audit score certified
  - Tests apuntan a `127.0.0.1:1` con `timeout 5` para evitar red real

## Compliance

- Rule #8: Slice 2 sobre spec PROPOSED, scaffolding + wrapper (no cambia reglas, no cambia agents)
- Egress limitado a URL provided por user
- No credenciales, no PII
- BSD-3 compatible (dep futura, no añadida aún)

## Próximos slices

- Slice 3 (M, 6h): `tech-research-agent` + `web-research` skill fallback path
- Slice 4 (S, 3h): MCP server opt-in registration

## Referencias

- Spec: `docs/propuestas/SE-061-scrapling-research-backend.md`
- Slice 1: `scripts/scrapling-probe.sh` (batch 14, #655)
- Roadmap: Era 183 Tier 3 Champions
