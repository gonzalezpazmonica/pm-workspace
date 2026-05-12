# Interrupted Session Persistence — Regla canónica

> **REGLA INMUTABLE** — Cuando una sesión humana de Savia debe cerrarse a medias
> (reinicio, fin de jornada, cambio de máquina, OpenCode tool-healing roto, etc.),
> el estado se persiste SIEMPRE en una ruta única y conocida.

## Path canónico

```
{workspace}/.savia-memory/sessions/RESUME-{slug}.md
```

- `{workspace}` resuelto via `scripts/savia-env.sh` (`SAVIA_WORKSPACE_DIR`).
- `.savia-memory/` está **gitignored** (N3 — usuario, fuera del repo público).
- `sessions/` agrupa sólo los handoffs de sesión humana interrumpida.
- `RESUME-{slug}.md` — un fichero por hilo de trabajo en curso.
  `{slug}` describe el tema (`obsidian-hubs`, `pr-spec-project-update-f1`, etc.).

## Diferencia con otros stores

| Caso | Path | Quién lo usa |
|---|---|---|
| Sesión humana interrumpida (esta regla) | `.savia-memory/sessions/RESUME-*.md` | Humano al reabrir Savia |
| Handoff entre agentes (SDD pipeline) | bloque YAML inline en output | Agente receptor |
| Handoff longform multi-agente | `docs/agent-notes/*.md` | Otros agentes |
| Auto-memory persistente (decisiones, feedback) | `.claude/external-memory/auto/` + `memory-store.sh` | Savia entre sesiones |
| Handoffs históricos legacy | `~/.savia/handoffs/HANDOFF-*.md` | Sólo lectura, no escribir aquí |

## Cuándo escribir un RESUME

Savia escribe (o actualiza) `RESUME-{slug}.md` cuando:

1. El usuario indica cierre explícito ("me voy", "cierro", "reinicio").
2. Se detecta inestabilidad de OpenCode (tool-healing, plugin roto, etc.) que
   obligará a reiniciar.
3. Hay trabajo en curso que NO está committed/pusheado y que no cabe en
   auto-memory (>5 items o >100 tokens por item).
4. La rama tiene commits ahead de origin pendientes de push.

## Contenido mínimo (template)

```markdown
# Sesión interrumpida — {tema}

**Fecha**: YYYY-MM-DD
**Rama**: {branch}
**HEAD**: {sha} ({N} ahead de origin/main)
**Motivo del cierre**: {razón}

## Estado actual
{qué está hecho, qué falta, qué está bloqueado}

## Acción requerida al reabrir
\`\`\`bash
{comando exacto para retomar}
\`\`\`

## TODOs pendientes
- [ ] ...

## Contexto crítico
{decisiones tomadas, ficheros tocados, gotchas}

## Stashes / artefactos temporales
{rutas en /tmp/savia-stash/ u otros}
```

## Cómo recuperar

```bash
ls .savia-memory/sessions/
cat .savia-memory/sessions/RESUME-{slug}.md
```

Savia debe ofrecer recuperación proactivamente al inicio de sesión si detecta
ficheros en `.savia-memory/sessions/` con mtime < 7 días.

## Limpieza

- Al completar el trabajo (PR mergeado, tarea cerrada), **borrar** el
  `RESUME-{slug}.md` correspondiente.
- RESUMEs con mtime > 30 días → archivar en
  `.savia-memory/sessions/archive/YYYY-MM/` o borrar si ya no aplican.

## Prohibiciones

- NUNCA persistir RESUMEs en `~/.savia/handoffs/` (legacy, sólo lectura).
- NUNCA escribir RESUMEs en rutas dentro del repo trackeadas por git.
- NUNCA incluir credenciales, PATs, tokens en el RESUME (aplica
  `pii-sanitization.md` y `data-sovereignty.md`).
- NUNCA commitear `.savia-memory/` — debe estar en `.gitignore`.
