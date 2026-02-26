---
name: help
description: >
  Muestra todos los comandos disponibles agrupados por categoría, con parámetros
  y ejemplos. Detecta el estado del workspace y recomienda primeros pasos si
  hay configuración pendiente.
---

# Ayuda de PM-Workspace

**Filtro:** $ARGUMENTS

> Uso: `/help` (todo) · `/help sprint` (categoría) · `/help --setup` (solo primeros pasos)

---

## Protocolo

### 1. Detectar estado del workspace (memoria de primeros pasos)

Comprobar cada punto y registrar los pendientes:

| Paso | Qué comprobar | Cómo |
|---|---|---|
| 1. PAT | Existe fichero en `AZURE_DEVOPS_PAT_FILE` | `test -f $HOME/.azure/devops-pat` |
| 2. Organización | `AZURE_DEVOPS_ORG_URL` no contiene "MI-ORGANIZACION" | Leer CLAUDE.md |
| 3. PM identificado | `AZURE_DEVOPS_PM_USER` no es placeholder | Leer pm-config.md |
| 4. Proyecto registrado | Existe `projects/*/CLAUDE.md` | Buscar en projects/ |
| 5. Equipo definido | Existe `projects/*/equipo.md` | Buscar en projects/ |
| 6. Conexión verificada | Existe `output/test-workspace-*.md` | Buscar en output/ |

### 2. Presentar primeros pasos (si hay pendientes)

Si hay pasos pendientes, mostrarlos ANTES del catálogo:

```
══════════════════════════════════════════════════════
  🚀 PRIMEROS PASOS — {N} pendientes de 6
══════════════════════════════════════════════════════

  ⬜/✅ Paso 1: Configurar PAT → crear $HOME/.azure/devops-pat
  ⬜/✅ Paso 2: Configurar organización → editar CLAUDE.md
  ⬜/✅ Paso 3: Identificar PM → editar pm-config.md (AZURE_DEVOPS_PM_USER)
  ⬜/✅ Paso 4: Registrar primer proyecto → /context:load o crear projects/{nombre}/
  ⬜/✅ Paso 5: Definir equipo → crear equipo.md en el proyecto
  ⬜/✅ Paso 6: Verificar conexión → ejecutar scripts/test-workspace.sh --mock

  📖 Guía completa: docs/SETUP.md
══════════════════════════════════════════════════════
```

Si todos completados → `✅ Workspace configurado — todos los pasos completados.`

### 3. Mostrar catálogo de comandos

Leer `.claude/commands/references/command-catalog.md` y presentar los comandos.

Si `$ARGUMENTS` contiene un filtro, mostrar solo la categoría:

| Argumento | Categoría |
|---|---|
| `sprint`, `report`, `kpi`, `board` | Sprint y Reporting |
| `pbi`, `discovery`, `jtbd`, `prd` | PBI y Discovery |
| `spec`, `sdd`, `agent` | SDD |
| `pr`, `review`, `quality` | Calidad y PRs |
| `team`, `onboarding`, `evaluate` | Equipo y Onboarding |
| `infra`, `env`, `cloud` | Infraestructura y Entornos |
| `--setup`, `setup`, `start` | Solo primeros pasos (omitir catálogo) |
| (vacío) | Todo |

### 4. Formato de presentación

Para cada comando mostrar: nombre, descripción de una línea, parámetros (obligatorios y opcionales), y un ejemplo de uso.

Agrupar por categoría con separadores visuales. Ver formato completo en `references/command-catalog.md`.

---

## Restricciones

- **Solo lectura** — no modifica ningún fichero
- Si no puede determinar el estado de un paso, marcarlo como ⚠️ (no verificable)
- No mostrar datos sensibles (PAT, secrets) en el output
