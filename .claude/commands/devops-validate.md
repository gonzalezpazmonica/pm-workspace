---
name: devops-validate
description: >
  Validate Azure DevOps project configuration against pm-workspace
  ideal Agile requirements. Generates remediation plan if mismatches found.
tier: extended
---

# /devops-validate

**Argumentos:** $ARGUMENTS

> Uso: `/devops-validate --project {p} [--team {t}]`

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 /devops-validate — Azure DevOps Configuration Audit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Si no se indica `--project`, preguntar interactivamente.
Si no se indica `--team`, usar `"{project} Team"` como default.

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Infrastructure** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/tools.md`
   - `profiles/users/{slug}/projects.md`
3. Adaptar output según herramientas y entorno del usuario
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Verificar prerequisitos

```
Verificando requisitos...
```

Mostrar ✅/❌:
- PAT de Azure DevOps (`$HOME/.azure/devops-pat` existe)
- Org URL configurada (`AZURE_DEVOPS_ORG_URL` no contiene placeholder)
- `curl` y `jq` disponibles

Si falta el PAT → modo interactivo: pedir, guardar en `$HOME/.azure/devops-pat`, continuar.
Si falta Org URL → pedir interactivamente, guardar en `CLAUDE.local.md`.

## 4. Ejecución con progreso

```
📋 Paso 1/4 — Verificando conectividad y proyecto...
📋 Paso 2/4 — Auditando process template y work item types...
📋 Paso 3/4 — Verificando campos y configuración de backlog...
📋 Paso 4/4 — Verificando sprints e iteraciones...
```

Ejecutar: `bash scripts/validate-devops.sh --project "$PROJECT" --team "$TEAM" --output "$OUTPUT_FILE"`

Donde `OUTPUT_FILE` = `output/validations/YYYYMMDD-devops-validate-{project}.json`

## 5. Mostrar resultado

Parsear el JSON report. Presentar tabla resumen:

```
## DevOps Validation Report — {project}

| # | Check | Status | Details |
|---|-------|--------|---------|
| 1 | Connectivity | ✅ PASS | PAT authentication successful |
| 2 | Project | ✅ PASS | Project found |
| ... | ... | ... | ... |

**Summary:** {pass} PASS · {warn} WARN · {fail} FAIL
```

Si **todos PASS**: `✅ Project is ready for pm-workspace.`

Si hay **WARN o FAIL** → generar plan de remediación:

```
## Remediation Plan (requires manual approval)

### 🔴 FAIL — Process template
Action: Organization Settings > Process > Change process to Agile
Impact: Blocking — WIQL queries expect Agile types and states

### 🟡 WARN — Bug behavior
Action: Project Settings > Boards > Team config > Bugs as requirements
Impact: Bugs won't appear in backlog alongside User Stories
```

Preguntar: `¿Deseas que guarde el plan de remediación en un fichero?`

## 6. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{status_icon} /devops-validate — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Report: output/validations/YYYYMMDD-devops-validate-{project}.json
📊 {pass} PASS · {warn} WARN · {fail} FAIL
💡 Si todos PASS → ejecuta /sprint-status para verificar datos reales
⚡ /compact — Ejecuta para liberar contexto antes del siguiente comando
```
