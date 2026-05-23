---
name: exit
description: >
  Cierra la sesión actual de forma limpia: persiste el estado en ROADMAP.md,
  guarda un RESUME-{slug}.md con el goal de la próxima sesión, hace commit
  opcional del roadmap, y deja todo listo para retomar tras un cuelgue.
---

# /exit — Cierre de sesión persistente

**Argumentos:** `$ARGUMENTS` (opcional: slug del goal de la próxima sesión, ej. `fix-env-loader`)

> Complementa a `/session-save` con foco en el roadmap vivo
> (`.savia-memory/sessions/ROADMAP.md`) y el RESUME de continuidad.

## 1. Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/exit — Cerrando sesión y persistiendo estado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Resumen de la sesión actual

Recopilar mentalmente:

- **Branch activa**: `git branch --show-current`
- **Commits hechos en esta sesión**: `git log --oneline @{u}..HEAD 2>/dev/null || git log --oneline -10`
- **Estado git**: `git status --short`
- **Items completados**: revisar TodoWrite y el ROADMAP.md actual
- **Items pendientes / diferidos**: lo que NO se cerró

## 3. Actualizar ROADMAP.md

1. Leer `.savia-memory/sessions/ROADMAP.md`
2. Marcar como `Hecho` los items que se completaron en esta sesión
3. Mover items diferidos a la sección "Deuda diferida" con razón explícita
4. Actualizar el campo "Última actualización" con la fecha de hoy
5. Si la sesión cambió de branch, actualizar "Sesión activa → Branch"
6. Escribir el fichero modificado

## 4. Crear/actualizar RESUME de continuidad

Slug: usar `$ARGUMENTS` si se pasó, si no inferir del último foco de la sesión (p.ej. nombre de branch o título del goal).

Path: `.savia-memory/sessions/RESUME-{slug}.md`

Estructura:
```markdown
# RESUME — {slug}

> Persistido: {fecha} (cierre sesión vía /exit)
> Última actualización: {fecha} — Goal explícito de la próxima sesión

## Goal próxima sesión (declarado por el usuario)

{1-2 frases con el objetivo claro}

## Estado actual

- Branch: `{branch}`
- HEAD: `{sha-corto} {mensaje}`
- Commits pendientes de push: {N}

## Plan de ataque (próxima sesión)

1. ...
2. ...
3. ...

## Comandos para retomar

```bash
git checkout {branch}
cat .savia-memory/sessions/ROADMAP.md | head -50
{otros}
```

## Otros pendientes diferidos

- ...
```

Si el RESUME del slug ya existe → actualizar, no sobreescribir entero (preservar histórico previo en una sección "Sesiones anteriores").

## 5. Commit opcional del roadmap

Si `git status --short .savia-memory/` muestra cambios:

```bash
git add .savia-memory/sessions/ROADMAP.md .savia-memory/sessions/RESUME-*.md
# NO commit automático — propuesta al usuario
echo "Cambios en .savia-memory/ listos. ¿Hacer commit ahora? (sugerencia: hazlo en una rama de docs)"
```

> NO hacer commit autónomo (autonomous-safety.md: nada se mergea sin /pr-plan).
> Solo proponer y dejar `git add` hecho si el usuario lo aprueba.

## 6. Resumen final (banner de salida)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sesión cerrada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ROADMAP:    .savia-memory/sessions/ROADMAP.md ({lineas} líneas)
RESUME:     .savia-memory/sessions/RESUME-{slug}.md
Branch:     {branch}
Pendientes: {N} items diferidos (ver ROADMAP § Deuda diferida)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Para retomar:
  cat .savia-memory/sessions/ROADMAP.md | head -50
  cat .savia-memory/sessions/RESUME-{slug}.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 7. Notas operativas

- `/exit` **NO** ejecuta `/clear`. Si el usuario quiere limpiar contexto después, lo hace explícito.
- `/exit` **NO** cierra OpenCode/Claude Code. Es un comando de persistencia, no de proceso.
- Si el frontend se cuelga ANTES de invocar `/exit`, el `ROADMAP.md` (actualizado durante la sesión) ya tiene el estado mínimo recuperable.
- Diferencia con `/session-save`: `session-save` hace dump completo de decisiones y resultados; `/exit` enfoca en continuidad y goal próxima sesión.

## 8. Manejo de errores

- Si no existe `.savia-memory/sessions/`, crearlo (`mkdir -p`).
- Si no existe `ROADMAP.md`, crearlo desde la plantilla mínima:
  ```markdown
  # Session Roadmap
  > Persistido: {fecha}
  ## Sesión activa
  Branch: {branch}
  ## Estado actual
  (vacío al arranque)
  ```
- Si git no está inicializado o el repo no es git, omitir la sección de commit y avisar.
