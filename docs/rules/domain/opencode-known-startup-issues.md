---
context_tier: L2
token_budget: 400
---

# OpenCode Known Startup Issues — SE-234

Referencia de errores conocidos en el log de arranque de OpenCode.
No todos los mensajes de error indican un fallo real.

## ERROR: MCP -32601 Method not found (codebase-memory-mcp)

```
ERROR service=mcp clientName=codebase-memory-mcp error=MCP error -32601: Method not found failed to get resources
ERROR service=mcp clientName=codebase-memory-mcp error=MCP error -32601: Method not found failed to get prompts
```

**Severidad real:** INFORMATIVO — no es un error.

**Causa:** OpenCode intenta llamar `resources/list` y `prompts/list` en todos los
MCP servers al arrancar. `codebase-memory-mcp` v0.8.1 implementa 14 tools pero
no implementa los endpoints opcionales de resources ni prompts (válido en la
especificación MCP). OpenCode lo registra como ERROR aunque el server funciona
correctamente.

**Acción requerida:** Ninguna. Ignorar estos mensajes.

**Verificar que el server funciona:**
```bash
/home/monica/.local/bin/codebase-memory-mcp --version
# Debe mostrar: codebase-memory-mcp 0.8.x
```

## WARN: duplicate skill name (×N) — CORREGIDO en SE-234

**Causa original:** El symlink `.opencode/.claude → ../.claude` hacía que OpenCode
escaneara TANTO `.claude/skills/` COMO `.opencode/skills/` (que apunta al mismo
directorio físico), registrando cada skill dos veces.

**Fix aplicado:** Eliminar el symlink `.opencode/.claude`. OpenCode solo escanea
`.opencode/skills/` (su directorio canónico), que ya apunta a `.claude/skills/`.

**Si reaparecen:** Verificar que `.opencode/.claude` no fue recreado.

## ERROR: ppt MCP startup failed — CORREGIDO en SE-234

**Causa original:** La entrada `ppt` en `opencode.json` tenía `"$HOME"` literal en
el path del comando. JSON no expande variables de entorno — `$HOME` se pasa tal
cual a python3, que no encuentra el archivo.

**Fix aplicado:** Entrada `ppt` eliminada de `opencode.json`.

**Si reaparecen:** No añadir MCPs con rutas que usen `$HOME`. Usar rutas absolutas
resueltas o `~/.local/bin/nombre-binario`.
