## SE-234 — Fix 3 errores de arranque OpenCode

Fixed: 3 errores presentes en cada sesión de OpenCode:

1. ERROR: ppt MCP startup failed — $HOME no se expande en JSON.
   Entrada ppt eliminada de opencode.json.

2. WARN: duplicate skill name ×105 — symlink .opencode/.claude causaba
   doble escaneo de .claude/skills/. Symlink eliminado.

3. ERROR: MCP -32601 Method not found — falso positivo de codebase-memory-mcp
   (no implementa endpoints opcionales de resources/prompts). Documentado.
