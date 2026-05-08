---
id: SE-064
title: SE-064 — ACM multi-host generator (Cursor/Windsurf/Copilot)
status: PROPOSED
origin: output/research-coderlm-20260421.md
author: Savia
priority: baja
effort: M 8h
gap_link: ACM solo consumible por Claude Code; otros IDEs reinventan el índice
approved_at: null
applied_at: null
expires: "2026-06-22"
---

# SE-064 — ACM multi-host generator

## Purpose

El sistema ACM produce markdown + frontmatter, consumido principalmente por Claude Code. Otros asistentes de código (Cursor, Windsurf, GitHub Copilot) usan sus propios formatos de reglas/contexto: `.cursorrules`, `.windsurfrules`, `.github/copilot-instructions.md`. Duplicar manualmente la información de ACM a cada formato es insostenible.

Patrón inspirado en coderlm: **single source of truth → multi-host generator**. El `.acm` se mantiene como origen; scripts lo proyectan a los formatos nativos de cada host.

Prioridad baja: solo adoptar cuando haya demanda real (usuario o proyecto que use Cursor/Windsurf activamente).

## Scope

### Slice 1 — Cursor export (S, 3h)

`scripts/acm-export-cursor.sh`:
- Lee `projects/{p}/.agent-maps/INDEX.acm` + `@include`s
- Genera `projects/{p}/.cursorrules` con secciones: arquitectura, entidades clave, convenciones
- Hash-driven: si `.acm` hash coincide con header del `.cursorrules`, no regenera
- `--dry-run` para preview
- BATS tests ≥ 15, score ≥ 80

### Slice 2 — Windsurf export (S, 2h)

`scripts/acm-export-windsurf.sh`:
- Genera `projects/{p}/.windsurfrules` (formato muy similar a cursor, plantilla reutilizable)
- Compartir library común con Slice 1 (`lib/acm-export-common.sh`)

### Slice 3 — Copilot export (S, 2h)

`scripts/acm-export-copilot.sh`:
- Genera `projects/{p}/.github/copilot-instructions.md`
- Formato markdown narrativo (no frontmatter)
- Respeta límite 20K caracteres de Copilot

### Slice 4 — Orchestrator + CI hook (XS, 1h)

`scripts/acm-export-all.sh`:
- Invoca los 3 exports por proyecto
- Integración con `/codemap:refresh --incremental` (auto-exporta post-refresh)
- Opcional: pre-commit hook que regenera si `.acm` cambia

## Acceptance criteria

- **Slice 1 PASS**: `acm-export-cursor.sh projects/proyecto-alpha` genera `.cursorrules` válido
- **Slice 2 PASS**: `acm-export-windsurf.sh` análogo
- **Slice 3 PASS**: `acm-export-copilot.sh` genera markdown ≤20K chars
- **Slice 4 PASS**: `acm-export-all.sh` exporta 3 formatos en un comando
- Hash-driven: re-ejecución sin cambio en ACM = no-op (idempotente)
- Cada export incluye header con `sha256` del ACM origen + fecha
- Zero regression: `.agent-maps/` intacto, solo se añaden ficheros target

## Risks

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Formatos Cursor/Windsurf cambian upstream | Alta | Medio | Versión pinned en header; alerta si parser falla |
| Proyectos privados filtran info por export | Media | Alto | Respetar `.confidential` markers del ACM; tests de PII |
| Duplicación que drifta | Alta | Medio | Hook post-refresh + verificación hash en CI |
| Baja adopción (nadie usa Cursor/Windsurf) | Alta | Bajo | Slice on-demand; no bloquear si no hay usuarios |
| Tamaño Copilot > 20K | Media | Medio | Slice 3 trunca + avisa |

## No hacen

- No reemplaza `.acm` como source of truth
- No sincroniza changes desde `.cursorrules` al `.acm` (unidireccional)
- No genera si proyecto no tiene `.agent-maps/` (skip)
- No toca configuración IDE del usuario

## Por qué Baja prioridad

- Cursor/Windsurf no son herramientas core del flujo pm-workspace actual
- Sin demanda real documentada (no hay issue ni user request)
- Riesgo de mantener 3 exporters sin usuarios
- Recomendación: **esperar a que un proyecto real lo pida** antes de ejecutar

Ejecutar solo si:
1. Usuaria reporta uso activo de Cursor/Windsurf en algún proyecto
2. O un proyecto se bifurca fuera de Claude Code y necesita paridad

## Referencias

- Research coderlm: `output/research-coderlm-20260421.md`
- Skill ACM: `.opencode/skills/agent-code-map/SKILL.md`
- Patrón multi-host coderlm: `github.com/JaredStewart/coderlm`
- Cursor rules docs: `cursor.sh/docs/rules`
- SE-063 enforcement hook (complementario, mayor prioridad)
