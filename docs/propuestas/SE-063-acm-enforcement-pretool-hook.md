---
id: SE-063
title: SE-063 — ACM enforcement pre-tool hook
status: PROPOSED
origin: output/research-coderlm-20260421.md
author: Savia
priority: Media
effort: S 4-6h
gap_link: Agentes hacen glob/grep masivo ignorando .agent-maps/ existentes
approved_at: null
applied_at: null
expires: "2026-05-22"
---

# SE-063 — ACM enforcement pre-tool hook

## Purpose

Los agentes Claude disponen de `.agent-maps/INDEX.acm` per-project pero el harness no garantiza su consulta antes de lanzar `Glob`/`Grep` amplios. Resultado: exploración ciega redundante que quema tokens y contradice el propósito del sistema ACM (SE-inspired por patrón coderlm).

Un pre-tool hook que bloquea queries amplias sin lectura previa del ACM del turno fuerza el workflow correcto sin depender de instrucciones en prompt.

## Scope

### Slice 1 — Hook detector (S, 2h)

`hooks/acm-enforcement.sh`:
- Registrado en `.claude/settings.json` como `PreToolUse` para `Glob`, `Grep`
- Detecta patrones "amplios": `**/*`, glob sin `path` restringido, grep sin `type`/`glob`/`path`
- Verifica si el turno actual ha leído un `.acm` (marker en `/tmp/savia-turn-{id}/acm-read`)
- Si query amplia + ACM no consultado + existe `projects/{p}/.agent-maps/INDEX.acm` → exit code 2 con mensaje guía
- BATS tests ≥ 15, score ≥ 80

### Slice 2 — Turn marker (XS, 1h)

`hooks/acm-turn-marker.sh`:
- `PostToolUse` para `Read` — si el path matchea `*.acm` o `.agent-maps/*`, crea marker
- Marker se limpia con turno nuevo (via `SessionStart` o TTL 10min)

### Slice 3 — Bypass semántico (S, 1-2h)

- Exención: si la query amplia es sobre `.claude/`, `docs/`, `scripts/` (infra del workspace, no código de proyecto) → no bloquear
- Exención: proyectos sin `.agent-maps/` → no bloquear
- Env var override `SAVIA_ACM_ENFORCE=0` para debugging (no default en CI)
- Log de cada bloqueo en `output/acm-enforcement.log` para análisis

## Acceptance criteria

- **Slice 1 PASS**: hook devuelve exit 2 ante `Grep pattern=".*" path="projects/X"` sin ACM previo
- **Slice 1 PASS**: hook devuelve exit 0 ante `Grep pattern="TODO" glob="*.py" path="projects/X/src"` (query acotada)
- **Slice 2 PASS**: tras `Read` de `projects/X/.agent-maps/INDEX.acm`, siguientes glob/grep amplios permitidos en el mismo turno
- **Slice 3 PASS**: queries sobre `docs/` no bloqueadas aunque ACM no consultado
- Zero regression: `scripts/readiness-check.sh` PASS post-merge
- Mensaje de bloqueo instructivo: "Lee `projects/{p}/.agent-maps/INDEX.acm` antes de grep/glob amplio"

## Risks

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Falsos positivos en queries legítimas amplias | Media | Medio | Slice 3 exenciones; env override documentado |
| Overhead por turno (stat del marker) | Baja | Bajo | Marker en tmpfs, <1ms |
| Agente entra en loop leyendo ACM repetidamente | Baja | Medio | Marker TTL 10min + cache |
| Proyectos sin ACM generado penalizados | Baja | Alto | Slice 3 skip si no existe INDEX.acm |
| Fricción percibida por usuario | Media | Bajo | Mensaje instructivo + log auditable |

## No hacen

- No genera ACM (eso es `/codemap:generate`)
- No bloquea `Read` ni `Bash` (solo Glob/Grep amplios)
- No aplica a workspace root (solo dentro de `projects/`)
- No gestiona ACM multi-host (eso es SE-064)

## Referencias

- Research coderlm: `output/research-coderlm-20260421.md`
- Skill ACM existente: `.claude/skills/agent-code-map/SKILL.md`
- Patrón inspirador: coderlm (MIT) hooks — `github.com/JaredStewart/coderlm`
- SE-060 hook injection guard (complementario)
- Rule #4 CLAUDE.md — "Leer `projects/{nombre}/CLAUDE.md` antes de actuar"
