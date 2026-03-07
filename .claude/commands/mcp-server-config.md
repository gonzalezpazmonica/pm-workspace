# Comando: /mcp-server-config

**Descripción:** Configura qué recursos, herramientas y prompts expone el servidor MCP.

## Uso

```
/mcp-server-config [--enable|--disable] {resource|tool|prompt}:{nombre}
/mcp-server-config --show
/mcp-server-config --reset
```

## Ejemplos

```
# Mostrar configuración actual
/mcp-server-config --show

# Desactivar recurso
/mcp-server-config --disable resource:risk-register

# Activar herramienta
/mcp-server-config --enable tool:generate-report

# Reiniciar a valores por defecto
/mcp-server-config --reset
```

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Configuración MCP Server
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Recursos (6 disponibles):
  ✅ project-list
  ✅ pbi-details
  ✅ task-status
  ✅ team-capacity
  ✅ sprint-metrics
  🔴 risk-register (desactivado)

Herramientas (4 disponibles):
  ✅ create-pbi
  ✅ update-task-status
  ✅ assign-task
  ✅ generate-report

Prompts (3 disponibles):
  ✅ sprint-planning
  ✅ pbi-decomposition
  ✅ risk-assessment

Configuración guardada en: .claude/mcp-server-config.json
💡 Reinicia el servidor para aplicar cambios: /mcp-server-start {mode}
```

Nota: Los cambios se guardan en `.claude/mcp-server-config.json` y requieren reiniciar el servidor.
