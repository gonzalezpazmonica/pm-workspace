---
name: help
description: Catálogo de comandos y primeros pasos pendientes.
---

Filtro: $ARGUMENTS

## 1. Detectar stack

Leer `CLAUDE.local.md` → buscar `AZURE_DEVOPS_ENABLED`.
- `false` → Stack = **GitHub-only**
- `true` o ausente → Stack = **Azure DevOps**

## 2. Si $ARGUMENTS = --setup → Solo checks (NO catálogo)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /help --setup — Verificación del workspace
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Stack: {tipo}
```

**Checks comunes:** Proyecto (`projects/*/CLAUDE.md`), Equipo (`projects/*/equipo.md`), Test (`output/test-workspace-*.md`).
**GitHub-only:** GitHub Connector (`GITHUB_CONNECTOR = true`), Repo git (`test -d .git`).
**Azure DevOps:** PAT, Org (no placeholder), PM user (no placeholder).

Mostrar ✅/❌ por cada uno. Si hay ❌ → modo interactivo (ver §4).

Terminar con:
```
✅ Verificación completada — N/N checks OK (stack: {tipo})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 Para ver comandos disponibles: /help
```

**STOP aquí. NO mostrar catálogo tras --setup.**

## 3. Si $ARGUMENTS ≠ --setup → Catálogo (output-first)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /help — Catálogo de comandos
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Stack: {tipo}
```

**Guardar catálogo completo** en `output/help-catalog.md` (por categorías, con descripciones).
**Mostrar en chat SOLO resumen** (máx 15 líneas):

```
📋 Comandos disponibles: {N} / 83 total

  Calidad y PRs (4) · Governance (5) · Legacy (3)
  Project Onboarding (5) · Diagramas (4) · Infra (7)
  Equipo (3) · Mensajería (6) · Conectores (12)
  Utilidades (4)

  No disponibles (Azure DevOps): Sprint (10), PBI (6), SDD (5),
  Pipelines (5), Repos (6), DevOps Extended (5)

📄 Catálogo completo: output/help-catalog.md
💡 Siguiente: /project:audit --project {nombre}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Si $ARGUMENTS filtra por categoría → mostrar solo esa categoría inline (pocas líneas).

## 4. Modo interactivo (solo desde --setup, solo si hay ❌)

Para CADA check fallido:
1. Explicar qué es y por qué es necesario
2. Preguntar si quiere configurarlo ahora
3. Si sí → pedir dato → guardarlo → confirmar

**Proyecto faltante:** crear `projects/{nombre}/CLAUDE.md` + entrada en `CLAUDE.local.md`.
**Equipo faltante:** pedir miembros → guardar `projects/{nombre}/equipo.md`.
**Test:** ejecutar `bash scripts/test-workspace.sh --mock`.
**PAT** (Azure DevOps): guardar en `$HOME/.azure/devops-pat`.
**Org** (Azure DevOps): reemplazar placeholder en CLAUDE.md.
**PM user** (Azure DevOps): reemplazar placeholder en CLAUDE.md.
**GitHub Connector:** solo informar (no modificar ficheros).

## 5. Restricciones

- Solo lectura (salvo modo interactivo de --setup)
- No mostrar secrets (PAT, tokens)
- **NO crear secciones, variables o ficheros no definidos en este comando**
- **NO editar CLAUDE.local.md** salvo añadir entrada en tabla de Proyectos Activos
- **--setup NUNCA muestra catálogo** — solo checks
- **Catálogo se guarda en fichero** — solo resumen en chat
