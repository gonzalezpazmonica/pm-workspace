---
name: savia-vaults
description: Usar cuando se interactua con SaviaVaults — cupulas de contexto, busqueda federada, servidores MCP/A2A, backups, confidencialidad. Triggers: 'crea una cupula', 'indexa documentacion', 'busca en los vaults', 'federate este dome', 'backup del conocimiento', 'nivel de confidencialidad', 'gestiona cupulas', 'context dome', 'vaults CLI'. NOT para diseno de arquitectura de conocimiento (usar context-dome-manager agent).
maturity: stable
context: project
category: knowledge-management
priority: high
tags: [vaults, cupulas, contexto, federacion, mcp, a2a, backup, confidencialidad]
recommends: [context-dome, knowledge-graph, ubiquitous-language]
---

# SaviaVaults — Operacion de Cupulas de Contexto

Gestiona cupulas de contexto via SaviaVaults: crea domes, busca, federa, backups, confidencialidad.

## Cuando usar

- "crea una cupula de contexto para..."
- "indexa la documentacion en un dome"
- "busca en los vaults / cupulas"
- "federa este dome con..."
- "haz backup de las cupulas"
- "cambia el nivel de confidencialidad"
- "arranca/para el servidor de vaults"

## Comandos esenciales

### Crear y gestionar domes

```bash
vaults dome create <nombre>
vaults dome list
vaults dome info <nombre>
vaults dome rename <old> <new>
vaults dome delete <nombre>
vaults dome sync <nombre> --source <dir>
vaults dome index <nombre> --force
```

### Servidores

```bash
vaults server start --name <dome> --transport mcp
vaults server start --name <dome> --transport a2a
vaults server start --name <dome> --transport both
vaults server stop --name <dome>
vaults server status --name <dome>
vaults server logs --name <dome> --follow
```

### Busqueda

```bash
vaults dome search "termino" --dome <nombre>
vaults dome search "termino" --federated
vaults search "termino"
```

### Federacion

```bash
vaults dome federate add <id> <url> [--token <t>] [--weight <w>]
vaults dome federate remove <id>
vaults dome federate list
vaults dome federate health
```

### Backups

```bash
vaults backup create --name <dome> --compress
vaults backup list
vaults backup restore <id> --target <dir> --dry-run
vaults backup schedule "0 2 * * *" --name <dome>
vaults backup status
```

### Confidencialidad

```bash
vaults confidentiality set N2 --dome <nombre>
vaults confidentiality get --dome <nombre>
vaults confidentiality audit --dome <nombre>
```

### Usuarios

```bash
vaults user add <user> --role admin|reader|writer --dome <dome>
vaults user list --dome <dome>
vaults user passwd <user> --dome <dome>
vaults user perm <user> <perm> <true|false> --dome <dome>
```

### Salud y config

```bash
vaults health
vaults config show
```

## Flujos de trabajo comunes

### Flujo 1: Crear cupula desde documentacion existente

```bash
vaults dome create mi-docs
vaults dome sync mi-docs --source ./docs
vaults dome index mi-docs
vaults server start --name mi-docs --transport both
```

### Flujo 2: Federar dos cupulas

```bash
# En maquina A
vaults server start --name alpha --transport a2a --port 8923
# En maquina B
vaults dome federate add alpha http://HOST_A:8923 --token TOKEN
vaults dome search "termino" --federated
```

### Flujo 3: Backup y restaurar

```bash
vaults backup create --name docs --compress
vaults backup restore backup-docs-ID --target /tmp/restored
```

## Integracion MCP

SaviaVaults expone 9 MCP tools. Si el servidor MCP esta corriendo:

| Tool | Uso |
|---|---|
| vault_read | Leer nota por path |
| vault_write | Crear/actualizar nota |
| vault_search | Busqueda con snippets |
| vault_list | Arbol de directorios |
| vault_stats | Estadisticas |
| vault_index | Reconstruir indice |
| vault_diff | Git diff |
| vault_log | Historial git |
| vault_tags | Tags con conteos |

## Anti-patrones

- NO borrar un dome sin backup previo.
- NO exponer domes con datos sensibles sin token de autenticacion.
- NO federar en bucle (A->B->C->A). Maximo 1 hop.
- NO usar --force en delete sin confirmacion del usuario.
- NO modificar .savia-vault/ a mano. Usa los comandos vaults.

## Roadmap

Para decisiones estrategicas de arquitectura de conocimiento, delegar al agente context-dome-manager.

Para generar CONTEXT_DOME.md de modulos con bus factor bajo, usar el skill context-dome.
