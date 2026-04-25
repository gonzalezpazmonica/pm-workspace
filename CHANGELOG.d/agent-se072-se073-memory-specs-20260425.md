# Dos nuevas specs APPROVED — SE-072 + SE-073 (GenericAgent research)

**Date:** 2026-04-25
**Version:** 6.0.0

## Summary

Research de `lsdefine/GenericAgent` (6.8k ⭐, Apr 2026) produjo 2 specs nuevas S-effort con fit claro en memoria de Savia. Status APPROVED (listas para implementar en PRs separadas tras review humana).

## Cambios

### A. SE-072 — Verified Memory axiom

`docs/propuestas/SE-072-verified-memory-axiom.md`:
- **Axioma "No Execution, No Memory"**: `memory-store.sh save` requerirá `--source <origin>` con valores enumerados (tool/file/verified/user)
- Hook PreToolUse `memory-verified-gate.sh` bloqueará writes a `auto/MEMORY.md` sin citation
- Grandfathering: entries existentes no se tocan, solo gate NUEVAS
- AC-01..AC-05 definidos. Effort S (3h)
- Doctrine doc `verified-memory-axiom.md` a crear
- Riesgos: fricción de developer (mitigable con mensaje didáctico)

### B. SE-073 — MEMORY.md L1 hard-cap tiered

`docs/propuestas/SE-073-memory-index-cap-tiered.md`:
- **Cap 200 → 30 líneas** en MEMORY.md principal (reduce token cost per turn)
- 2-tier system:
  - Tier A (HIGH-FREQ): inline en MEMORY.md, entries accessed ≥3× en 30d
  - Tier B (LOW-FREQ): filename-only en MEMORY-ARCHIVE.md
- `scripts/memory-tier-rotate.sh` script manual/cron rotando A↔B por access_count
- Access counter en frontmatter de cada memory file
- Current state: 30 entries ~= 30 líneas. Cap 30 es apretado pero alcanzable HOY. Evita drift silencioso hacia cap 200 laxo actual.
- AC-01..AC-06 definidos. Effort S (3h)
- Riesgo principal: calibración del algoritmo de rotation (start 3/30d, measure 1 mes)

### C. Origen del research

GenericAgent (lsdefine/GenericAgent):
- 6.8k stars, MIT, Python ~3K LoC
- 9 tools atómicos + 2 de memoria
- Agent loop ~100 líneas con `_done_hooks` reentrantes
- Memoria L0-L4 estricta
- Filosofía: no precargar skills, cristalizarlas por uso

De los 7 patterns analyzados, 2 adoptables por Savia (estas specs), 5 ya cubiertos por nuestro stack (skill registry 86 skills, Truth Tribunal, autonomous-safety, dag-execute, dev-session/feasibility-probe), 6 descartados (browser login persist, self-bootstrap, api externa cn, WeChat/QQ bots, ADB hardware).

Veredicto: "ADOPTAR LUEGO" — estas 2 specs son los wins claros.

## Validacion

- `scripts/readiness-check.sh`: PASS (solo nuevos specs + CHANGELOG, sin código)

## Progreso backlog APPROVED

Post-merge de este PR:
- APPROVED: **4 → 6** (+2 nuevos, GPU-blocked y SE-072/SE-073 ejecutables)
- PROPOSED: **70 → 68** (-2 promoted directamente a APPROVED post-research)

Queue APPROVED ejecutable en dev (sin GPU):
- **SE-072** Verified Memory axiom (S, 3h)
- **SE-073** MEMORY.md L1 cap tiered (S, 3h)

GPU-blocked (4, sin cambios): SE-028, SE-042, SPEC-023, SPEC-080.

## No hacen (explicit)

- **No implementa** SE-072 ni SE-073 en este PR. Solo crea specs para review humana.
- **No modifica** memory existente (grandfathering).
- **No cambia** memory-store.sh, MEMORY.md, ni hooks actuales. Cero riesgo regression.

## Referencias

- Research completo: arriba en este CHANGELOG (resumen en 500 palabras)
- SE-072: `docs/propuestas/SE-072-verified-memory-axiom.md`
- SE-073: `docs/propuestas/SE-073-memory-index-cap-tiered.md`
- Source: https://github.com/lsdefine/GenericAgent
