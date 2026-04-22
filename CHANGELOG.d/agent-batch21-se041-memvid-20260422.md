# Batch 21 — SE-041 Slice 2 memvid-backup skill

**Date:** 2026-04-22
**Branch:** `agent/batch21-se041-memvid-skill-20260422`
**Version bump:** 5.69.0

## Summary

Quinto champion Tier 3 (post-SE-061, SE-035, SE-032, SE-033). Evaluación de memvid como formato portable para backup/travel de memoria externa. Slice 2 implementa contrato completo + tar-gzip con SHA256 integrity. Slice 3 integrará memvid API real tras acceptance criteria.

## Added

- `scripts/memvid-backup.py`:
  - 3 subcomandos: `pack`, `restore`, `verify`
  - SHA256 integrity check en pack + verify
  - Fallback `tar-gzip` cuando memvid no disponible
  - Flag `--format` (auto|memvid|tar-gzip)
  - Detection `try_memvid_available()` sin cargar el paquete
  - JSON output estructurado (`--json`)
  - Exit codes: 0 OK, 1 runtime error, 2 usage

- `.claude/skills/memvid-backup/SKILL.md` + `DOMAIN.md`:
  - Documentación 3 subcomandos con ejemplos
  - Integración con travel-pack workflow
  - Criterios acceptance SE-041 checklist
  - Tradeoffs documentados (pros/contras)

- `tests/test-memvid-backup.bats` (40 tests certified):
  - Script existence + shebang + executable
  - Pack (output creation, sha256, latency, size, format, error on nonexistent src)
  - Verify (valid backup, sha256 report, member count, nonexistent/empty/corrupted errors)
  - Restore (extraction, files_extracted count, nonexistent error)
  - Round-trip (content preservation, reproducibility)
  - Usage errors (no subcommand, unknown, missing required)
  - Skill structure (under 150 lines, SE-041 refs, 3 subcommands documented)
  - Coverage (pack_tar_gzip, try_memvid_available, sha256_file)
  - Edge cases (empty dir, long filenames, zero-member detected)
  - Isolation (verify read-only, --help offline)

## Changed

- `CLAUDE.md`: skills count 82 → 83

## Compliance

- Rule #8: Slice 2 sobre SE-041 spec PROPOSED. Contract + tar-gzip implementation + skill + tests
- Validación funcional: round-trip pack→verify→restore preserva contenido, SHA256 calculado correctamente
- Zero egress (tar-gzip nativo); memvid opt-in con aviso en skill

## Acceptance SE-041 status

| # | Criterio | Target | Estado |
|---|---|---|---|
| a | Ingest 100 engrams <30s | bench | pendiente Slice 3 |
| b | Retrieval top-5 p50 <50ms | bench | pendiente Slice 3 |
| c | Round-trip byte-identical | SHA256 | **cumplido** |
| d | Integracion travel-pack sin cloud | zero-deps | **cumplido** (tar-gzip) |

## Roadmap Tier 3 status

1. ✅ SE-061 Scrapling (4 slices, 103 tests)
2. ✅ SE-035 Mutation testing Slice 2 (33 tests)
3. ✅ SE-032 Reranker Slice 2 (36 tests)
4. ✅ SE-033 BERTopic Slice 2 (37 tests)
5. ✅ SE-041 Memvid Slice 2 (this batch, 40 tests)
6. ⏳ SE-028 Oumi training pipeline (requiere GPU, diferido)

## Referencias

- Spec: `docs/propuestas/SE-041-memvid-portable-memory.md`
- Probe: `scripts/memvid-probe.sh` (batch 11)
- Roadmap: `docs/ROADMAP.md` §Era 183 Tier 3 Champions
