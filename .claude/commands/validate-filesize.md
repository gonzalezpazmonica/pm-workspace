---
name: validate-filesize
description: Validar que ficheros del workspace cumplen ≤150 líneas
agent: commit-guardian
---

# /validate-filesize

Verifica que todos los ficheros gestionados del workspace (skills, agents, rules, commands) cumplen la regla de ≤150 líneas.

---

## Flujo

### 1. Banner inicio

```
╔══════════════════════════════════════╗
║  📏 Validate File Size              ║
╚══════════════════════════════════════╝
```

### 2. Escanear ficheros

Categorías a revisar:
- `.claude/skills/*/SKILL.md`
- `.claude/agents/*.md`
- `.claude/rules/domain/*.md`
- `.claude/commands/*.md`
- `scripts/*.sh`
- `CLAUDE.md`

### 3. Validar

Para cada fichero:
```bash
lines=$(wc -l < "$file")
if [ "$lines" -gt 150 ]; then
    echo "❌ FAIL: $file ($lines líneas)"
fi
```

### 4. Resumen

```
📊 Resultado: X ficheros revisados, Y ok, Z exceden 150 líneas
```

Excepciones conocidas (legacy): ficheros en `rules/languages/` pueden exceder.

### 5. Banner fin

```
╔══════════════════════════════════════╗
║  ✅ File Size Validation — Completo ║
╚══════════════════════════════════════╝
⚡ /compact
```
