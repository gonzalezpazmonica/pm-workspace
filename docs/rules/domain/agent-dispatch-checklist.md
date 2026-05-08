---
globs: [".opencode/agents/**", "CHANGELOG.md"]
---

# Regla: Checklist de Dispatch a Agentes

Antes de enviar un prompt a un subagente (Tool: Task), el orquestador DEBE
incluir contexto suficiente para que el agente cumpla las convenciones del
proyecto. El hook `agent-dispatch-validate.sh` valida automáticamente.

## Checklists por tipo de tarea

### Crear commands (.opencode/commands/*.md)

- [ ] Mencionar frontmatter obligatorio: `name` + `description`
- [ ] Incluir ejemplo de un command existente como referencia de formato
- [ ] Especificar límite de 150 líneas
- [ ] Si el command tiene `$ARGUMENTS`, documentar su formato

### Modificar CHANGELOG.md

- [ ] Indicar leer la versión actual antes de escribir (versión más alta)
- [ ] Exigir orden descendente estricto de versiones
- [ ] Prohibir reemplazo completo del fichero — solo insertar nueva entrada
- [ ] Exigir formato `## [x.y.z] — YYYY-MM-DD`
- [ ] Incluir link comparativo al final: `[x.y.z]: .../compare/...`

### Crear skills (.opencode/skills/*/SKILL.md)

- [ ] Especificar límite de 150 líneas
- [ ] Exigir frontmatter YAML: `name`, `description`, `context`
- [ ] Pedir DOMAIN.md acompañante (Clara Philosophy)
- [ ] Referenciar skill existente como modelo de formato

### Crear rules (docs/rules/domain/*.md)

- [ ] Especificar límite recomendado de 150 líneas (warn)
- [ ] Indicar formato: título con `#`, secciones claras, sin frontmatter

### Git push / PR / merge

- [ ] Incluir paso de validación CI: `bash scripts/validate-ci-local.sh`
- [ ] Verificar que no se está en rama main

## Hook automático

El hook `agent-dispatch-validate.sh` (PreToolUse, matcher: Task):
- **BLOQUEA** (exit 2) si falta contexto crítico para CHANGELOG o frontmatter
- **AVISA** (exit 0 + mensaje) si falta contexto recomendado
- Se ejecuta antes de cada invocación de subagente
- Ref: `.claude/settings.json` → PreToolUse → Task
