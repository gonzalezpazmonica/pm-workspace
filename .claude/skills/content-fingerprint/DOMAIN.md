# DOMAIN — content-fingerprint

> Companion de `SKILL.md`. Documenta el dominio, no se carga en runtime.

## Por que existe esta skill

El workspace tiene 41+ archivos que invocan `sha256sum | cut -c1-N` para
producir identificadores cortos a partir de contenido. Cuatro de ellos lo
hacen para el mismo proposito (cache key, pattern signature, audit hash,
file fingerprint) sin ninguna abstraccion compartida. CLAUDE.md Rule #6
dice "repetition 2+ debe consolidarse en skill". Esta skill consolida el
patron en un punto unico, descubrible, testeado y con frontmatter
`bioquimica:` declarativo que documenta la inspiracion biologica honesta.

## Conceptos de dominio

- **Content fingerprint**: hash determinista corto (8/16/32/64 chars hex)
  derivado por sha256 truncado.
- **Avalanche**: cambio de 1 byte en input produce cambio total en output.
- **Determinismo**: mismo input siempre produce mismo output.
- **DNA barcoding (analogia)**: fragmento canonico discriminativo (Hebert 2003).
- **Drosophila LSH (referencia futura)**: random projection + winner-take-all
  (Dasgupta 2017). NO implementado aqui.

## Limites y no-objetivos

- NO detecta near-duplicates (1 byte cambia el fingerprint entero).
- NO es LSH biologico (Dasgupta 2017 requiere vectorizacion previa).
- NO sustituye memory-vector.py (HNSW + MiniLM) para busqueda semantica.
- NO se usa para integridad criptografica fuerte (usar sha256sum directo).
- NO migra los 4 callers ciegamente; solo los 2 sin fallback chain.

## Confidencialidad

- Nivel: N2 (interno workspace).
- Output: hex hashes son N1 (publico) por naturaleza determinista.
- Cache: cualquier caller puede persistir hashes en su almacen propio.

## Referencias

- Spec: docs/specs/SE-151-content-fingerprint-consolidation.spec.md
- Tests: tests/scripts/content-fingerprint.bats (14 tests)
- Fixtures: tests/fixtures/fingerprint/ (30 etiquetated)
- DOIs validados: 10.1098/rspb.2002.2218 (Hebert), 10.1126/science.aam9868 (Dasgupta)
- Lecciones previas: docs/learning/biomimetic-investigation-protocol.md
- Reglas: CLAUDE.md Rule #6 (repetition 2+ → skill), Rule #8 (no merge sin spec)
