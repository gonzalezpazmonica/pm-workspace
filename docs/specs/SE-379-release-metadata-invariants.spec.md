# SE-379 — Release & Metadata Invariants

**Estado:** APPROVED — Mónica (operadora), 2026-09-05: "Apruebo todas, implementa, pr y merge"
**Prioridad:** P1 · **Developer Type:** agent-single · **Context Risk:** low
**Origen:** auditoría externa §10 (CONFIRMED)

## 1. Motivación

Hoy es posible publicar inconsistencias públicas básicas. Evidencia viva (2026-09-05): contadores de comandos divergentes — 532 (`README.md:5`), 567 (disco), 571 (`CLAUDE.md`), 295 (`.scm/INDEX.scm:3`) — y traducciones `README.ca/gl/pt.md` con números propios desactualizados. `.github/workflows/release.yml` solo extrae notas del changelog; no valida nada.

## 2. Alcance

`scripts/release-invariants.sh --check` ejecutable local y en CI.

### Invariantes y códigos

| Código | Detecta |
|---|---|
| `VERSION_REGRESSION` | SemVer retrocede o hay dos versiones "actuales" |
| `CHANGELOG_VERSION_MISMATCH` | CHANGELOG ≠ versión del repo/release |
| `STALE_COUNTER` | Contador manual ≠ contador derivado del registry (SE-375) |
| `CAPABILITY_COUNT_MISMATCH` | README vs traducciones vs CLAUDE.md vs .scm |
| `STALE_TRANSLATION` | Traducción sin refrescar tras cambio de contadores |
| `ROADMAP_TIMESTAMP_DRIFT` | Roadmap activo con fecha incoherente |
| `GENERATED_VIEW_DRIFT` | Vista generada editada a mano / regeneración difiere |

## 3. Criterios de aceptación

- Fixture por invariante que hace fallar CI de forma aislada (7 fixtures).
- `--check` exit 0 en repo sano, exit 1 con mensaje y código por cada invariante rota.
- Runtime ≤10s, sin red, sin deps nuevas (stdlib + jq).

## 4. Dependencias

Contadores canónicos desde SE-375. Hasta que SE-375 exista, esta spec compara las superficies entre sí (detección de divergencia sin fuente canónica) y se completa después.

## 5. OpenCode Implementation Plan

### Clasificación
- **Tier:** 2 · **Agent-capable:** yes
- **Slices:** S1 release-invariants.sh --check --root (7 invariantes) · S2 fixtures + bats por invariante · S3 counters canónicos desde SE-375

## Referencias

- Auditoría externa §10 · SE-375 · `pr-plan-gates.sh` G5/G5b · `ci-reliability-gate.sh` (SPEC-SE-012)
