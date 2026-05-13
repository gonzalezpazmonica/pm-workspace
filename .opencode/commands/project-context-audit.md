---
description: Audit static/dynamic ratio in projects/<slug>/CLAUDE.md
argument-hint: <project-slug>
allowed-tools: Bash
---

# /project-context-audit

Audita el ratio static/dynamic de un `projects/<slug>/CLAUDE.md` para optimizar
el prefix cache (SPEC-PROJECT-CONTEXT-DISCIPLINE).

**Modo:** siempre informativo. NUNCA bloquea writes. Cuando se cumplen los
prerequisitos de SPEC-CACHE-HIT-TRACKING (>=200 turns en 14d con file_path
prefijo `projects/<slug>/CLAUDE.md`), cruza el ratio teorico con el hit rate
observado en `~/.savia/usage.db`.

## Uso

```
/project-context-audit <slug>
```

Ejemplos:
- `/project-context-audit trazabios_main`

## Salida

```
Project: trazabios_main
File:    projects/trazabios_main/CLAUDE.md  (471 lines)
Ratio:   static=312 (66%), dynamic=98 (21%), unmarked=61 (13%)
Status:  WARNING (target: static >=80%)

[INFORMATIONAL MODE — SPEC-CACHE-HIT-TRACKING pending]

UNMARKED blocks:
  L120  ## Sprint 2026-09 — pendientes
  L245  ## Riesgos activos

DYNAMIC blocks candidatos a extracción:
  L120  → projects/trazabios_main/context/sprint-2026-09-pendientes.md
```

## Implementación

```bash
python3 "${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-.}}/scripts/project-context-audit.py" "$@"
```

## Referencias

- Convención de marcadores: `docs/rules/domain/project-context-discipline.md`
- Hook PreToolUse: `.opencode/hooks/project-context-discipline.sh`
- Spec: `docs/specs/SPEC-PROJECT-CONTEXT-DISCIPLINE.spec.md`
- Dependencia: SPEC-CACHE-HIT-TRACKING (para enforcing mode con hit rate observado)
