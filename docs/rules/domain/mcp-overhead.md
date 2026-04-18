# MCP Token Overhead — doctrina pm-workspace

> **Regla**: los MCP servers cuestan tokens en CADA mensaje, no solo al arrancar. Auditar + podar + cargar on-demand.

## Principio

Cada MCP server activo envia sus tool definitions (schemas, parametros, descripciones) en el payload de cada mensaje del agente. No hay cross-turn caching para ellos (a diferencia del prompt caching del system prompt). Resultado: 5 servers tipicos con 30-50 tools → 10-20k tokens/turn permanentes, antes de que el agente diga nada.

En una context window de 200k (Claude Sonnet/Opus), 15-20k tokens de overhead MCP son **~10% consumido en aire**. En sesiones de 20+ turnos, el coste acumulado en tokens de entrada es significativo.

## Formula heuristica

```
tokens_por_turno ≈ Σ (tools_del_server × 200) + (char_count_descripciones ÷ 4)
```

Rango por tool: 100-500 tokens dependiendo de verbosity de schema + descripcion.

## Estado pm-workspace (2026-04-18)

`.claude/mcp.json` contiene `mcpServers: {}` vacio con un comment explicito:

> "MCP Servers para PM-Workspace. Savia los conecta bajo demanda con `/mcp-server start {nombre}`. No se cargan al arranque para garantizar inicio rapido."

Ningun proyecto anida `mcpServers` en su config. `~/.claude.json` no registra servers a nivel user.

**Overhead real**: 0 tokens/turn de MCP user-configurados. Diseno actual ya es optimo.

Los unicos MCPs presentes son built-ins de Claude Code (claude.ai Gmail / Drive / Calendar) que suman ~1-3k tokens/turn en auth tools — no controlables desde pm-workspace, vienen con el CLI.

## Patron recomendado

**NO hacer**:
```json
// En config global ~/.claude.json o settings.json:
{
  "mcpServers": {
    "filesystem": { ... 20 tools },
    "git": { ... 15 tools },
    "database": { ... 25 tools },
    "search": { ... 10 tools },
    "slack": { ... 30 tools }
  }
}
// → ~15-20k tokens/turn permanentes incluso en sesiones donde no los usas
```

**SI hacer**:
```json
// .claude/mcp.json vacio a nivel workspace
{ "mcpServers": {} }

// Per-project: solo lo que ese proyecto usa
// projects/savia-web/.mcp.json:
{ "mcpServers": { "playwright": { ... } } }

// O mejor: on-demand via comando runtime (/mcp-server start playwright)
```

## Tool: `scripts/mcp-audit.sh`

Audita configs actuales, estima tokens/turn, emite veredicto contra presupuesto:

```bash
bash scripts/mcp-audit.sh                  # human readable
bash scripts/mcp-audit.sh --json           # machine readable
bash scripts/mcp-audit.sh --budget 5000    # custom budget
```

Exit codes: `0` bajo presupuesto, `1` sobre presupuesto, `2` error input.

Integrable en CI para detectar overhead creciente antes de que sea problema.

## Checklist al anadir un MCP server

- [ ] ¿El server va a usarse en >50% de las sesiones? Si no → config per-project o on-demand.
- [ ] ¿Cuantos tools expone? Si >20 → evaluar si todos son necesarios o el server permite filtrar.
- [ ] ¿Las descripciones de tools son 1-2 lineas? Si no → comprimir (ahorro ~60-80 tokens/tool).
- [ ] ¿Coexiste con otro server que hace lo mismo? Elegir uno.
- [ ] ¿El server tendria sentido como skill local en lugar de MCP externo? Los skills no tienen overhead per-turn.

## Referencias

- MindStudio analysis: https://www.mindstudio.ai/blog/claude-code-mcp-server-token-overhead
- `.claude/external-memory/auto/feedback_mcp_overhead.md` (memoria persistida)
- Skills relacionados: `mcp-server`, `mcp-recommend`, `mcp-browse`, `mcp-server-config`
- Comando runtime: `/mcp-server start|stop|status|config`
