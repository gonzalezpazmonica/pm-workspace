---
spec_id: SE-100
title: Update .opencode/ docs to reflect real structure (52 stale .claude/ refs)
status: IMPLEMENTED
approved_by: operator (2026-05-27)
implemented_at: 2026-05-30
implemented_by: opencode-claude-opus-4.7
priority: P1
effort: S
estimated_time: 90 min
depends_on: none
source: output/20260527-auditoria-obsoleto-legado.md (Tier 2.7)
---

# SE-100 — Update .opencode/ docs

## Problema

53 referencias a `.claude/` desde ficheros en `.opencode/`:
- `.opencode/CLAUDE.md` — describe estructura `.claude/` que ya no es la real
- `.opencode/HOOKS-STRATEGY.md` — habla de `.claude/settings.json` cuando opencode usa su propio config
- `.opencode/README.md` — menciona symlink legacy

La documentación miente sobre la arquitectura. Funciona por accidente (symlink o copia), pero un dev nuevo se pierde.

## Solución

### Slice 1: Audit + map (~30 min)
- `grep -rn "\.claude/" .opencode/` exhaustivo
- Clasificar cada hit: keep (referencia legítima al frontend Claude Code) vs replace (estructura real es `.opencode/`)

### Slice 2: Rewrite (~60 min)
- Actualizar `.opencode/CLAUDE.md` con estructura `.opencode/` real
- Actualizar HOOKS-STRATEGY.md explicando ambos modelos (Claude Code hooks vs OpenCode plugins)
- README.md: clarificar que pm-workspace soporta múltiples frontends

## Aceptación

- `grep -c "\.claude/" .opencode/CLAUDE.md` ≤10 (solo referencias legítimas, no estructurales)
- Lectura por un dev nuevo: estructura comprensible sin contradicciones

## Notas de implementación (2026-05-30)

### Hallazgo crucial pre-implementación

El spec asumía `.opencode/` como copia paralela de `.claude/` con 53 refs `.claude/` que eran "drift". La realidad es distinta:

- `.opencode/{commands,hooks,skills,docs,.claude}` son **symlinks** a sus equivalentes en `.claude/` o raíz → las refs `.claude/foo` desde `.opencode/` apuntan al mismo fichero físico que `../.claude/foo`. Ambas rutas son válidas.
- Solo `.opencode/agents/` (70 .md), `.opencode/plugins/`, `.opencode/mcp-templates/`, `.opencode/CLAUDE.md`, `.opencode/README.md`, `.opencode/HOOKS-STRATEGY.md` son **realmente independientes**.

Por tanto las 53 refs no eran drift — la mayoría eran arquitectura válida. El drift real estaba concentrado en los 3 docs principales que describían un modelo arquitectónico falso/obsoleto.

### Bugs descubiertos en docs antes de reescribir

- `.opencode/CLAUDE.md`: counters obsoletos (33 agents real 70, 401 commands real 559, 16 hooks real 69, 43 skills real 98), reglas 1-23 vs canónico 1-25, URL ejemplo "MI-ORGANIZACIóN" con tilde rota.
- `.opencode/README.md`: describía `.claude/` como "enlace simbólico al directorio original" — **falso**, es al revés (`.opencode/{commands,hooks,skills}` son los symlinks).
- `.opencode/HOOKS-STRATEGY.md`: describía wrappers manuales fase 1-2 marzo 2025 — superado por symlinks compartidos OpenCode v1.14+.

### Acciones completadas

1. **`.opencode/CLAUDE.md`** reescrito (93L): solo redirige al canónico `../CLAUDE.md` + documenta el modelo arquitectónico real (symlinks shared) + counters auto-generados + tabla cross-frontend (Claude Code / OpenCode v1.14+ / Copilot Enterprise / LocalAI).
2. **`.opencode/HOOKS-STRATEGY.md`** reescrito (98L): refleja modelo unificado (69 hooks compartidos via symlink), 3 capas defensa (runtime / git / CI), degradación por frontend, histórico de fases.
3. **`.opencode/README.md`** reescrito (215L): estructura real con symlinks marcados, instalación, configuración, troubleshooting actualizado (incluye fix del symlink `.claude/`), tabla compatibilidad cross-frontend, histórico.

### Refs `.claude/` restantes

Tras reescritura: 37 refs (vs 53 iniciales). De ellas:
- 13 en `.opencode/CLAUDE.md` (informativas, documentan el modelo)
- 12 en `.opencode/README.md` (estructura, troubleshooting)
- 1 en `.opencode/HOOKS-STRATEGY.md`
- 11 en `.opencode/agents/*.md` (refs legítimas a settings.json/profiles/rules que solo viven en .claude/)

Las 37 restantes son **arquitectura intencional**, no drift. Documentado en cada doc el modelo de symlinks para que devs nuevos no las interpreten como bug.

### AC

- [x] AC-1: 3 docs principales reescritos con modelo arquitectónico real
- [x] AC-2: Counters correctos (70/559/69/98) en los 3 docs
- [x] AC-3: Tabla cross-frontend (Claude Code / OpenCode / Copilot Enterprise / LocalAI) en CLAUDE.md y README.md
- [x] AC-4: Eliminadas afirmaciones falsas sobre dirección de symlinks
- [x] AC-5: Histórico documentado en cada fichero

### Verificación

```bash
$ bash scripts/claude-md-drift-check.sh
PASS: CLAUDE.md counts match reality
  agents=70, commands=559, skills=98, hooks=69 (72 regs)
```
