# Comando: /mcp-server-status

**Descripción:** Muestra estado actual del servidor MCP.

## Uso

```
/mcp-server-status
```

## Resultado

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 MCP Server Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Estado: ✅ Ejecutándose | 🛑 Detenido

Modo: local | remote
Endpoint: stdio | http://localhost:3000
Autenticación: ninguna | Bearer token

Estadísticas:
  Conexiones activas: N
  Requests procesados: N (total sesión)
  Uptime: X horas Y minutos
  Última actividad: YYYY-MM-DD HH:mm:ss UTC

Recursos expuestos: 6/6
Herramientas expuestas: 4/4
Prompts expuestos: 3/3

Modo solo lectura: activado | desactivado

Errores recientes: ninguno | lista de últimos 3
```

Si el servidor no está ejecutándose:
```
🛑 MCP Server no está ejecutándose.
   Inicia con: /mcp-server-start {local|remote}
```
