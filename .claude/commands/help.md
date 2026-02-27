---
name: help
description: Catálogo de comandos y primeros pasos pendientes.
---

Filtro: $ARGUMENTS

Aplica siempre @.claude/rules/command-ux-feedback.md

Muestra la ayuda de PM-Workspace. Pasos:

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /help — Catálogo y estado del workspace
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Detección de stack

Leer `CLAUDE.local.md` en la raíz del workspace. Buscar la sección `## ⚙️ Stack del Workspace`.

**Si existe y contiene `AZURE_DEVOPS_ENABLED = false`:**
- Stack = **GitHub-only**
- Mostrar: `📦 Stack detectado: GitHub-only (Azure DevOps desactivado)`

**Si existe y contiene `AZURE_DEVOPS_ENABLED = true` (o no tiene esa variable):**
- Stack = **Azure DevOps**
- Mostrar: `📦 Stack detectado: Azure DevOps`

**Si la sección NO existe en `CLAUDE.local.md`:**
- Stack = **Azure DevOps** (por defecto, ya que CLAUDE.md define constantes Azure DevOps)
- Mostrar: `📦 Stack detectado: Azure DevOps (por defecto)`

## 3. Setup (siempre, o si $ARGUMENTS = --setup)

Mostrar: `Verificando configuración del workspace...`

### 3a. Checks comunes (ambos stacks)

Mostrar ✅ o ❌ por cada uno:
- **Proyecto:** existe `projects/*/CLAUDE.md`
- **Equipo:** existe `projects/*/equipo.md`
- **Test:** existe `output/test-workspace-*.md`

### 3b. Checks Azure DevOps (SOLO si stack = Azure DevOps)

Mostrar ✅ o ❌ por cada uno:
- **PAT:** `test -f $HOME/.azure/devops-pat`
- **Org:** AZURE_DEVOPS_ORG_URL no contiene "MI-ORGANIZACION"
- **PM:** AZURE_DEVOPS_PM_USER no es placeholder

### 3c. Checks GitHub-only (SOLO si stack = GitHub-only)

Mostrar ✅ o ❌ por cada uno:
- **GitHub Connector:** `GITHUB_CONNECTOR = true` en CLAUDE.local.md
- **Repo accesible:** el directorio raíz es un repo git (`test -d .git`)

### Si hay ❌ → Modo interactivo

Para CADA check fallido, seguir este flujo exacto:
1. Explicar qué es y por qué es necesario
2. Preguntar si quiere configurarlo ahora
3. Si dice sí → pedir el dato y guardarlo en el fichero indicado abajo
4. Confirmar que se guardó

**Proyecto faltante** (ambos stacks):
- Explicar: "Cada proyecto necesita su propio CLAUDE.md con la configuración específica"
- Preguntar: "¿Cómo se llama tu proyecto?"
- Crear: `projects/{nombre}/CLAUDE.md` desde plantilla
- Añadir entrada en `CLAUDE.local.md` tabla de Proyectos Activos

**Equipo faltante** (ambos stacks):
- Explicar: "equipo.md contiene los miembros y sus competencias"
- Preguntar: "¿Quieres crear el fichero de equipo ahora?"
- Si sí: pedir nombre, email y rol de cada miembro (loop hasta que diga "fin")
- Guardar: `projects/{nombre}/equipo.md`

**Test no ejecutado** (ambos stacks):
- Explicar: "El test del workspace verifica que todo funciona"
- Preguntar: "¿Quieres ejecutar el test ahora? (puede tardar ~2 min)"
- Si sí: ejecutar `bash scripts/test-workspace.sh --mock`

**PAT faltante** (solo Azure DevOps):
- Explicar: "El Personal Access Token permite conectarse a Azure DevOps"
- Pedir: "Pega tu PAT (dev.azure.com → User Settings → Personal Access Tokens)"
- Guardar en: `$HOME/.azure/devops-pat` (sin salto de línea final)
- Verificar: longitud > 20 chars, sin espacios

**Org placeholder** (solo Azure DevOps):
- Pedir: "¿Cuál es tu URL? Ejemplo: https://dev.azure.com/mi-empresa"
- Guardar en: CLAUDE.md → reemplazar "MI-ORGANIZACION" por el valor real

**PM user placeholder** (solo Azure DevOps):
- Pedir: "¿Cuál es tu email en Azure DevOps?"
- Guardar en: CLAUDE.md → reemplazar placeholder en AZURE_DEVOPS_PM_USER

**GitHub Connector faltante** (solo GitHub-only):
- Explicar: "El conector GitHub en claude.ai da acceso enriquecido a repos e issues"
- Mostrar: "Actívalo en claude.ai/settings/connectors → GitHub"
- NO modificar ficheros — solo informar al usuario

### Después de resolver todos los ❌

```
✅ Verificación completada — N/N checks OK (stack: {tipo})
```

Si todo OK desde el principio:
```
✅ Workspace configurado correctamente (stack: {tipo})
```

## 4. Catálogo (si $ARGUMENTS no es --setup, o después del setup)

Mostrar comandos por categoría. Referencia completa: `.claude/commands/references/command-catalog.md`

**GitHub-only:** mostrar solo categorías que NO requieren Azure DevOps (Calidad, Governance, Legacy, Onboarding, Diagramas, Infra, Mensajería, Conectores, Utilidades = ~41 cmds). Listar las categorías Azure DevOps al final como "No disponibles (requieren Azure DevOps)".
**Azure DevOps:** mostrar todas las categorías (81 comandos).

Siguiente paso recomendado:
- GitHub-only: `Prueba: /project:audit --project {nombre} · /evaluate:repo {url}`
- Azure DevOps: `Prueba: /sprint:status --project {nombre} · /project:audit --project {nombre}`

## 5. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /help — Fin del catálogo ({N} disponibles / 81 total — stack: {tipo})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 6. Restricciones

- Solo lectura (salvo modo interactivo de --setup para los ficheros listados arriba)
- No mostrar secrets (PAT, tokens)
- El modo interactivo SOLO modifica los ficheros indicados explícitamente en cada check
- **NO crear secciones, variables o ficheros no definidos en este comando**
- **NO editar CLAUDE.local.md** salvo añadir entrada en tabla de Proyectos Activos al crear un proyecto nuevo
- Si $ARGUMENTS filtra por categoría, mostrar solo esa sección del catálogo
