# SE-284 — `vaults` CLI: Unified SaviaVaults Operations Command

> **Parent**: SE-280/281/282/283 (SaviaVaults)
> **Scope**: Cross-platform CLI for complete SaviaVaults lifecycle management
> **Stack**: TypeScript + Node.js 22+ + commander

## Metadatos

- **Task ID:** SE-284
- **PBI padre:** Era 200 — Savia Intelligence Layer
- **developer_type:** agent-team
- **status:** draft
- **stack:** TypeScript, commander, Node.js 22+
- **estimacion:** 14h (7 slices)

## Problema

SaviaVaults actualmente tiene comandos dispersos (`savia-vaults serve`, `savia-vaults federate add`, `savia-vaults search`). No hay un comando unificado que cubra el ciclo de vida completo: arranque/parada, gestion de cupulas, usuarios, copias de seguridad, confidencialidad. Cada operacion requiere recordar flags y paths diferentes.

## Objetivo

Un comando CLI unico llamado `vaults` que gestione TODA la operativa de SaviaVaults desde consola, tanto en Linux como en Windows, con:

- Sistema de help completo y navegable por arbol de comandos
- Gestion de servidores (MCP + A2A): start, stop, status, logs
- Gestion de cupulas: create, list, info, delete, federate, unfederate, sync
- Gestion de usuarios: add, remove, list, passwd, perm
- Copias de seguridad: create, list, restore, schedule (cron), unschedule, status
- Niveles de confidencialidad: set, get, list, audit
- Busqueda unificada: search con soporte federado
- Health check de todo el sistema

## Comando Tree

```
vaults
├── server
│   ├── start     [--name] [--transport mcp|a2a|both] [--port] [--tls]
│   ├── stop      [--name] [--force]
│   ├── restart   [--name]
│   ├── status    [--name]
│   └── logs      [--name] [--follow] [--lines N]
│
├── dome
│   ├── create    <name> [--path] [--template]
│   ├── list      [--format table|json]
│   ├── info      <name>
│   ├── delete    <name> [--force]
│   ├── rename    <name> <new-name>
│   ├── federate  add <id> <url> [--token] [--weight] [--tags]
│   ├── federate  remove <id>
│   ├── federate  list
│   ├── federate  health
│   ├── sync      <name> [--source <dir>]
│   ├── index     <name> [--force]
│   ├── stats     <name>
│   └── search    <query> [--dome] [--federated] [--max N]
│
├── user
│   ├── add       <username> [--role admin|reader|writer] [--dome]
│   ├── remove    <username> [--dome]
│   ├── list      [--dome] [--format table|json]
│   ├── passwd    <username> [--dome]
│   └── perm      <username> <permission> <value> [--dome]
│
├── backup
│   ├── create    [--name <dome>] [--output <dir>] [--compress]
│   ├── list      [--format table|json]
│   ├── restore   <backup-id> [--target <dir>] [--dry-run]
│   ├── schedule  <cron-expr> [--name <dome>] [--output <dir>]
│   ├── unschedule <schedule-id>
│   └── status    [--schedule-id]
│
├── confidentiality
│   ├── set       <level> [--dome <name>]  # N1(public) N2(internal) N3(confidential) N4(restricted)
│   ├── get       [--dome <name>]
│   ├── list      [--format table|json]
│   └── audit     [--dome <name>] [--output <file>]
│
├── config
│   ├── init      [--path]
│   ├── show      [--format json|yaml]
│   ├── edit      [--editor <path>]
│   └── validate  [--strict]
│
├── search        <query>  [--dome] [--federated] [--max N] [--format json|table]
├── stats         [--dome]
├── health        [--dome] [--federated]
├── version
└── help          [command]
```

## Arquitectura

```
vaults (CLI entry point)
  ├── cmd/server.ts      → start/stop/restart/status/logs
  ├── cmd/dome.ts        → create/list/info/delete/federate/sync/index/stats
  ├── cmd/user.ts        → add/remove/list/passwd/perm
  ├── cmd/backup.ts      → create/list/restore/schedule/unschedule/status
  ├── cmd/confidentiality.ts → set/get/list/audit
  ├── cmd/config.ts      → init/show/edit/validate
  ├── cmd/search.ts      → unified search
  ├── cmd/health.ts      → system health
  └── lib/
      ├── daemon.ts      → process management (PID files, start/stop)
      ├── cron.ts        → cron schedule management
      ├── vault-config.ts → config file read/write
      └── formatters.ts  → table, json, yaml output
```

## Implementacion

### Slice 1 — CLI framework + help system (2h)
- `src/cli/vaults.ts` — entry point con commander
- Sistema de help anidado con ejemplos
- `vaults help` y `vaults <cmd> --help`
- Auto-deteccion de plataforma (Linux vs Windows paths)

### Slice 2 — Server commands (2h)
- `vaults server start|stop|restart|status|logs`
- PID file en `.savia-vault/server.pid`
- Log file en `.savia-vault/server.log`
- Graceful shutdown (SIGTERM) + force kill (SIGKILL)

### Slice 3 — Dome commands (3h)
- `vaults dome create|list|info|delete|rename`
- `vaults dome federate add|remove|list|health`
- `vaults dome sync|index|stats|search`
- Integracion con FederationRegistry y SearchEngine

### Slice 4 — User commands (2h)
- `vaults user add|remove|list|passwd|perm`
- Almacenamiento en `.savia-vault/users.json`
- Passwords hasheados (bcrypt via Node crypto)
- Roles: admin (full), reader (read-only), writer (read+write)

### Slice 5 — Backup commands (2h)
- `vaults backup create|list|restore|schedule|unschedule|status`
- Backup: tar.gz de todo el vault
- Schedule via cron (integra con always-on-install-cron.sh)
- Restore con dry-run y validacion

### Slice 6 — Confidentiality + Config commands (2h)
- `vaults confidentiality set|get|list|audit`
- Niveles N1-N4 alineados con modelo Savia
- `vaults config init|show|edit|validate`
- Validacion contra JSON Schema

### Slice 7 — Installer updates + tests (1h)
- `install.sh`: symlink `vaults` a `/usr/local/bin/`
- `install.ps1`: Add to PATH on Windows
- Tests de integracion CLI

## Sistema de Help

```
$ vaults help
SaviaVaults CLI — manage context domes, servers, users, and backups.

Usage: vaults <command> [options]

Commands:
  server          Start, stop, and monitor vault servers
  dome            Create, manage, and federate context domes
  user            Manage vault users and permissions
  backup          Create, restore, and schedule backups
  confidentiality Set and audit confidentiality levels
  config          Manage vault configuration
  search          Search across local and federated domes
  stats           Show vault statistics
  health          System health check
  version         Show version
  help            Show this help

Examples:
  vaults server start --name my-docs --transport both
  vaults dome create team-knowledge --path ./vaults/team
  vaults dome federate add specs http://remote:8924 --token $TOKEN
  vaults backup create --name my-docs --compress
  vaults backup schedule "0 2 * * *" --name my-docs
  vaults confidentiality set N2 --dome team-knowledge
  vaults search "architecture" --federated
```

## Criterios de Aceptacion

**AC-1**: `vaults help` muestra arbol completo de comandos con ejemplos.

**AC-2**: `vaults server start` inicia servidor MCP/A2A y guarda PID.

**AC-3**: `vaults server stop` detiene servidor graceful, force si es necesario.

**AC-4**: `vaults dome create docs` crea vault con INDEX.md, MAP.md, .git.

**AC-5**: `vaults dome federate add specs http://remote` registra dome remoto.

**AC-6**: `vaults user add alice --role reader` crea usuario con permisos.

**AC-7**: `vaults backup create --compress` genera backup tar.gz verificable.

**AC-8**: `vaults backup schedule "0 2 * * *"` instala entrada cron.

**AC-9**: `vaults confidentiality set N3 --dome secrets` aplica nivel.

**AC-10**: `vaults config validate --strict` pasa contra JSON Schema.

**AC-11**: Funciona identico en Linux y Windows (paths adaptados).

**AC-12**: `vaults --version` muestra version del paquete.

## Self-Review — Edge Cases

1. **Server ya corriendo**: `start` detecta PID existente → error "already running (PID X)"
2. **Server no encontrado**: `stop` sin PID → busca por process name, o "not running"
3. **Dome con nombre duplicado**: `create` falla si el directorio ya existe
4. **Dome federado offline**: `federate health` muestra estado, no falla
5. **Usuario sin dome especificado**: Hereda del vault activo o error
6. **Password vacio**: `passwd` rechaza passwords < 8 chars
7. **Backup sin espacio**: `create` verifica espacio disponible antes de empezar
8. **Cron no instalado**: `schedule` advierte si cron no esta disponible
9. **Confidencialidad sin dome**: `confidentiality set` requiere --dome
10. **Config corrupta**: `validate` detecta JSON malformado, sugiere `config init`
11. **Windows paths**: `C:\Users\...` normalizados correctamente
12. **Ctrl+C en start**: graceful shutdown con cleanup de PID file
