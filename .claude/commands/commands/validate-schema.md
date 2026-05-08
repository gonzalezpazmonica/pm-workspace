---
name: validate-schema
description: Validar schema de frontmatter y settings.json
agent: commit-guardian
---

# /validate-schema

Valida que el frontmatter YAML de commands, skills, agents y rules siga el schema esperado, y que `.claude/settings.json` sea JSON válido.

---

## Flujo

### 1. Banner inicio

```
╔══════════════════════════════════════╗
║  🔍 Schema Validation               ║
╚══════════════════════════════════════╝
```

### 2. Validar settings.json

```bash
python3 -c "import json; json.load(open('.claude/settings.json'))" 2>&1
```

Verificar que:
- JSON válido
- Tiene key `hooks` con secciones válidas (SessionStart, PreToolUse, PostToolUse, Stop)
- Cada hook tiene `type`, `command`, y opcionalmente `timeout`, `statusMessage`

### 3. Validar frontmatter de commands

Para cada `.opencode/commands/*.md`:
- Debe tener frontmatter YAML válido (entre `---`)
- Campos requeridos: `name`, `description`
- Campo `name` debe coincidir con nombre de fichero (sin `.md`)
- Si tiene `agent:`, debe existir en `.opencode/agents/`

### 4. Validar frontmatter de skills

Para cada `.opencode/skills/*/SKILL.md`:
- Debe tener frontmatter YAML válido
- Campos requeridos: `name`, `description`
- Campo `context` debe ser `fork` o `main`

### 5. Resumen

```
📊 Resultado:
  settings.json: ✅ válido
  Commands: X validados, Y errores
  Skills: X validados, Y errores
```

### 6. Banner fin

```
╔══════════════════════════════════════╗
║  ✅ Schema Validation — Completo    ║
╚══════════════════════════════════════╝
⚡ /compact
```
