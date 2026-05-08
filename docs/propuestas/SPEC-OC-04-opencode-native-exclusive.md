# SPEC-OC-04 — OpenCode-Native Exclusive Migration

status: PROPOSED
> **Status:** DRAFT — pendiente de aprobación humana
> **Author:** Savia (sesión Mónica · branch `agent/spec-oc-04-opencode-native-20260506`)
> **Date:** 2026-05-06
> **Predecessors:** SPEC-127 (provider-agnostic env), SPEC-OC-01 (Shield port), SPEC-OC-02 (proxy Copilot, pendiente)
> **Risk level:** ALTO — afecta 1.500+ ficheros, irreversible sin esfuerzo grande

---

## 1. Problema

Savia actualmente vive en `.claude/` y se replica parcialmente en `.opencode/` vía symlinks. Coexisten dos frontends (Claude Code nativo + OpenCode) y el doble layout genera:

- Confusión sobre source of truth (3 sets de skills observables: `.opencode/skills/`, `.opencode/skills/SKILL.md`, generador `SKILLS.md`)
- Hooks bash (`.opencode/hooks/*.sh`) que OpenCode no ejecuta de forma nativa — solo 8 de 67 portados a TS plugins
- Variable `CLAUDE_PROJECT_DIR` hardcoded en 42 scripts/hooks (mitigada por `savia-env.sh` pero no eliminada)
- Symlink autoreferente `.opencode/.claude → ../.claude` (loop simbólico, peligroso si se sigue ciegamente)

## 2. Objetivo

Savia funciona **exactamente igual** desde la perspectiva del usuario, pero el directorio `.claude/` y la dependencia conceptual de "Claude Code como frontend" desaparecen. OpenCode pasa a ser el único frontend soportado.

### Out of scope

- Eliminar referencias en historial git, CHANGELOG, docs/propuestas (trazabilidad SDD)
- Cambiar el modelo subyacente (sigue siendo provider-agnostic vía SPEC-127)
- Renombrar `~/.savia-memory`, perfiles N3, datos N4 (ya neutrales)

## 3. Reglas de negocio

| ID | Regla |
|---|---|
| RN-OC04-01 | Cero pérdida funcional. Cada agent, skill, command, hook activo debe seguir disparándose con el mismo trigger. |
| RN-OC04-02 | Cero secretos expuestos. La migración no toca `~/.savia/`, vault ni credenciales. |
| RN-OC04-03 | Reversibilidad por slice. Cada slice es un commit atómico revertible sin tocar slices anteriores. |
| RN-OC04-04 | Shield siempre activo. Ningún slice deja Savia Shield degradado más allá del estado actual (Capa 2 NER, Capa 4 proxy). |
| RN-OC04-05 | Trazabilidad SDD. Historial git intacto. Cambios documentados en CHANGELOG.d/. |
| RN-OC04-06 | Aprobación humana antes de cada slice destructivo. Code Review (E1) obligatorio en cada PR. |
| RN-OC04-07 | Tests pasan a green al final de cada slice. Cobertura ≥ TEST_COVERAGE_MIN_PERCENT. |
| RN-OC04-08 | Si un slice rompe el repo, rollback inmediato vía `git revert`. No se acumula deuda. |

## 4. Scope cuantificado

| Artefacto | Conteo actual `.claude/` | Estado en `.opencode/` |
|---|---|---|
| Agents | 70 | 70 nativos (move-and-keep ya hecho parcialmente) |
| Skills | 96 SKILL.md | symlink — necesita move |
| Commands | 558 .md | symlink — necesita move + reformat OpenCode |
| Hooks bash | 67 .sh | 8 TS guards portados, 59 pendientes |
| Rules | 221 .md | symlink (vía docs/rules) — sigue accesible |
| Profiles | 1 directory | symlink — necesita move |
| Settings.json | 1 | reemplazar por opencode.json (parcialmente existe) |
| Refs `.claude/` activas | 664 ficheros | requieren rewrite |
| Refs `CLAUDE_PROJECT_DIR` | 42 ficheros | requieren rewrite a `OPENCODE_PROJECT_DIR` o `SAVIA_WORKSPACE_DIR` |

## 5. Slices

### Slice 1 — Foundation (zero-risk, reversible 100%)

**Objetivo:** Romper symlinks loop y consolidar source of truth de docs.

- [ ] Borrar symlink `.opencode/.claude` (loop autoreferente, sin uso real)
- [ ] Verificar AGENTS.md/SKILLS.md regen siguen funcionando
- [ ] Tests bats pasan
- [ ] Commit: `chore(oc-04): remove .opencode/.claude self-symlink`

**Criterio de éxito:** `find .opencode -type l -name .claude` devuelve 0. Suite tests verde.
**Rollback:** `git revert HEAD`.

### Slice 2 — Hook port priority batch (top-10 por peso)

**Objetivo:** Cerrar el hueco de 59 hooks bash sin equivalente TS.

- [ ] Ejecutar `scripts/hook-portability-classifier.sh` y obtener ranking
- [ ] Portar top-10 a `.opencode/plugins/guards/*.ts` (siguiendo patrón SPEC-OC-01)
- [ ] Tests TS pasan
- [ ] Documentar en CHANGELOG.d/

**Criterio:** 18/67 hooks con paridad funcional TS. Tests verdes.
**Rollback:** `git revert HEAD~1..HEAD`.

### Slice 3 — Skills move (.claude/skills → .opencode/skills)

**Objetivo:** Skills nativas en `.opencode/`.

- [ ] `git mv .opencode/skills/* .opencode/skills/` (solo skills NO ya presentes en .opencode/skills/)
- [ ] Resolver duplicados (algunas skills tienen dos versiones)
- [ ] Borrar symlink `.opencode/skills`
- [ ] Actualizar paths en hooks/scripts que referencien `.opencode/skills/`
- [ ] Regenerar SKILLS.md
- [ ] Tests bats verdes

**Criterio:** `.opencode/skills/*/SKILL.md` único source of truth. `.claude/skills` no existe.
**Rollback:** revert + restaurar symlink.

### Slice 4 — Commands move (558 .md)

**Objetivo:** Commands en formato OpenCode nativo.

- [ ] Auditar formato: ¿OpenCode usa el mismo frontmatter que Claude Code?
- [ ] Si idéntico: `git mv .claude/commands → .opencode/command/` (singular, OpenCode convention)
- [ ] Si diferente: script de conversión + verificación 1-by-1
- [ ] Actualizar refs (664 ficheros con paths `.opencode/commands/`)
- [ ] Borrar symlink

**Criterio:** Slash commands operativos en OpenCode. Tests por muestreo (10 commands críticos).
**Rollback:** revert.

### Slice 5 — Agents consolidación

**Objetivo:** `.opencode/agents/` único, `.opencode/agents/` borrado.

- [ ] Diff `.opencode/agents/*.md` vs `.opencode/agents/*.md` — resolver drift
- [ ] Borrar `.opencode/agents/`
- [ ] Actualizar refs en scripts/hooks
- [ ] Regenerar AGENTS.md

**Criterio:** Source of truth único. AGENTS.md regenerado.

### Slice 6 — Hooks remanentes + settings

**Objetivo:** Cerrar gap final de hooks y settings.

- [ ] Portar resto de hooks (49 restantes)
- [ ] Migrar `.claude/settings.json` → `opencode.json` config
- [ ] Verificar paridad funcional (cada hook activo ahora dispara como guard TS)
- [ ] Borrar `.opencode/hooks/`

**Criterio:** Cero `.sh` en flow activo. Solo TS guards.

### Slice 7 — Rules + profiles + cleanup final

**Objetivo:** Vaciar `.claude/`.

- [ ] Mover `.claude/rules/` → ¿`.opencode/rules/`? (los `docs/rules/` ya son neutrales)
- [ ] Mover `.claude/profiles/` → `.opencode/profiles/`
- [ ] Verificar `.claude/` vacío (excepto `worktrees/` y `external-memory/` si aplica)
- [ ] Decidir destino de `.claude/worktrees/` y `.claude/external-memory/`
- [ ] Renombrar `CLAUDE.md` → `OPENCODE.md` (o `AGENTS.md` ya cumple ese rol)
- [ ] Borrar `.claude/` definitivamente
- [ ] Renombrar `CLAUDE_PROJECT_DIR` → `OPENCODE_PROJECT_DIR` en 42 scripts (savia-env.sh ya gestiona fallback)

**Criterio:** `ls .claude/` devuelve "no such file or directory". Savia funciona idéntica.

### Slice 8 — Documentación pública + onboarding

**Objetivo:** Frontend único documentado.

- [ ] Reescribir README.md / README.en.md (frontend = OpenCode exclusivo)
- [ ] Actualizar docs/getting-started si existe
- [ ] Marcar SPEC-127 como "implementado parcialmente, superseded por SPEC-OC-04"
- [ ] Generar guía de migración para cualquier usuario que tuviera Claude Code instalado

**Criterio:** Cero menciones a "Claude Code como frontend" en docs activos. Historial intacto.

## 6. Riesgos

| ID | Riesgo | Probabilidad | Mitigación |
|---|---|---|---|
| R-01 | Hook bash sin port deja hueco de seguridad/UX | Alta hasta Slice 6 | Shield activo (TS guards ya cubren capas críticas). Slice 2 prioriza top-10. |
| R-02 | Symlinks rotos rompen scripts existentes | Alta en Slice 3-4 | Branch dedicada, suite tests por slice, rollback git revert. |
| R-03 | Drift entre `.opencode/agents/` y `.opencode/agents/` no detectado | Media | Slice 5 incluye diff explícito. |
| R-04 | Refs hardcoded en config local del usuario | Media | savia-env.sh ya soporta fallback. Aviso en release notes. |
| R-05 | Claude Code nativo (frontend antiguo) deja de funcionar | 100% (es el objetivo) | Comunicar a Mónica: post-migración, solo OpenCode. |
| R-06 | Commits intermedios dejan repo inconsistente | Media | Cada slice es self-contained y verde. |
| R-07 | Memoria persistente `.claude/external-memory/` se pierde | Baja | Slice 7 decide destino explícito antes de borrar. |
| R-08 | `.gitignore` necesita actualización | Baja | Verificar en cada slice. |

## 7. Criterios de aceptación

- [ ] AC-01: `ls .claude/` no existe tras Slice 7
- [ ] AC-02: 0 hooks bash en flow activo (todos portados a TS guards)
- [ ] AC-03: 0 referencias a `CLAUDE_PROJECT_DIR` en código activo (changelog/docs/propuestas exentos)
- [ ] AC-04: Suite tests bats verde
- [ ] AC-05: Suite tests TS verde
- [ ] AC-06: Shield Capa 1+5+6+8 operativa, daemon arriba
- [ ] AC-07: 70 agents accesibles vía OpenCode (`opencode agents list`)
- [ ] AC-08: 558 commands accesibles vía OpenCode (`/<cmd>`)
- [ ] AC-09: 96 skills resolvibles
- [ ] AC-10: AGENTS.md y SKILLS.md regenerables sin error
- [ ] AC-11: Historial git intacto (changelog/, docs/propuestas/, .git/ sin tocar)
- [ ] AC-12: README documenta OpenCode como frontend exclusivo

## 8. Coste estimado

| Slice | Esfuerzo | Riesgo |
|---|---|---|
| 1 | 30 min | trivial |
| 2 | 4-6h | medio |
| 3 | 2-3h | medio |
| 4 | 6-8h | alto |
| 5 | 2h | bajo |
| 6 | 6-8h | alto |
| 7 | 3-4h | medio |
| 8 | 2-3h | bajo |
| **TOTAL** | **~30h** | **alto agregado** |

Esto NO se hace en una sesión. Recomendación: una sesión por slice, con Code Review (E1) humano entre cada uno.

## 9. Plan de ejecución propuesto esta sesión

1. **Esta SPEC en draft** ✅ (este fichero)
2. **Mónica revisa y aprueba/modifica/rechaza**
3. Si APPROVED: ejecutar **Slice 1** (zero-risk, 30 min) en esta misma sesión, commit y parar
4. Slices 2-8 en sesiones posteriores con review humana entre cada uno

## 10. Decisión pendiente

Mónica debe responder antes de tocar nada más:

- (a) APPROVE: ejecuta Slice 1 ahora, resto en sesiones posteriores
- (b) MODIFY: indica qué cambiar en la SPEC
- (c) REJECT: para todo, plan alternativo
- (d) ALL-IN: ejecuta los 8 slices esta sesión (NO recomendado — viola Rule #8 SDD humano y autonomous-safety)

---

**Firma del autor:** Savia, en cumplimiento Rule #8 (SDD spec antes de implementar) y Rule #24 (radical honesty: el alcance es masivo y conviene fasear).
