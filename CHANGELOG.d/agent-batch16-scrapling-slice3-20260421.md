# Batch 16 — SE-061 Slice 3 skill integration

**Date:** 2026-04-21
**Branch:** `agent/batch16-scrapling-slice3-20260421`
**Version bump:** 5.64.0

## Summary

Tercer slice SE-061. Las dos skills de research (`tech-research-agent` + `web-research`) ahora documentan el fallback adaptativo a `scrapling-fetch.sh` cuando WebFetch devuelve 403/429/503 o extracción post-SearXNG requiere parser robusto. Nueva regla de dominio `research-stack.md` documenta la cadena de backends y las consideraciones legales.

## Added

- `docs/rules/domain/research-stack.md` (43 líneas):
  - Cadena de resolución: Cache → WebFetch → scrapling-fetch → curl
  - Matriz de backends por caso de uso
  - Reglas de robots.txt, rate limiting, ToS, GDPR, attribution
  - Observabilidad via `output/research-log.tsv` local

- `tests/test-research-stack.bats` (26 tests):
  - Rule file existence + constraints (<=150 líneas, references SE-061, direcciona robots/rate-limit/GDPR)
  - Skill integration (ambas skills referencian scrapling-fetch, SE-061, research-stack)
  - Script availability (scrapling-fetch.sh, scrapling-probe.sh executable)
  - Fallback contract (backend curl cuando scrapling ausente)
  - Negative + edge cases + isolation + coverage

## Changed

- `.claude/skills/tech-research-agent/SKILL.md`: +17 líneas con sección "Fallback de fetch (SE-061)"
- `.claude/skills/web-research/SKILL.md`: +13 líneas con sección "Scrapling enrichment (SE-061)"

## Compliance

- Rule #8: Slice 3 sobre spec PROPOSED. Cambios sólo en docs/skills (no código ejecutable nuevo más allá del ya aprobado en slices previos)
- Zero egress, zero credenciales, rule docs sin PII
- La regla documenta que NO se debe bypass paywalls ni scrapear sites con captcha/login

## Próximos

- Slice 4 (S, 3h): MCP server opt-in registration (`scrapling[ai]` en `.claude/mcp.json`)

## Referencias

- Spec: `docs/propuestas/SE-061-scrapling-research-backend.md`
- Slice 1: `scripts/scrapling-probe.sh` (PR #655)
- Slice 2: `scripts/scrapling-fetch.sh` (PR #656)
