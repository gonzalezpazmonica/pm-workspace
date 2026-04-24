---
id: SE-058
title: SE-058 — MCP Security Audit
status: IMPLEMENTED
origin: output/research/agentshield-20260420.md (inspired by agentshield 23 MCP rules)
author: Savia
priority: alta
effort: M 8h
gap_link: MCP supply chain sin auditar (npx -y, auto-approve, remote transport)
approved_at: "2026-04-21"
applied_at: "2026-04-21"
batches: [12]
expires: "2026-05-20"
---

# SE-058 — MCP Security Audit

## Purpose

Nuestros MCP servers declarados en `.claude/mcp.json` (y otros puntos de registro) carecen de auditoría de seguridad. Vulnerabilidades típicas del ecosistema MCP:

- **Supply chain**: `npx -y` sin pin de version (RCE por typosquatting)
- **Auto-approve**: `autoApprove: true` bypassea consent del usuario
- **Transport inseguro**: `transport: "shell"` o endpoints remotos sin autenticación
- **Hardcoded secrets**: tokens en `env` o `args`
- **Args peligrosos**: shell metacharacters, rutas absolutas a directorios sensibles

Cost of inaction: un MCP malicioso puede exfiltrar secrets, ejecutar comandos arbitrarios o comprometer sesión de Claude Code completa. Gap identificado en audit 2026-04-20.

## Scope (Slice 1)

`scripts/mcp-security-audit.sh`:
- Audita `.claude/mcp.json` + `~/.claude.json` mcpServers block
- Reporta findings por severidad (CRITICAL / HIGH / MEDIUM / LOW)
- Output human + JSON
- Exit codes: 0 clean, 1 findings, 2 usage error

## Reglas (11 checks Slice 1)

| ID | Rule | Severity |
|---|---|---|
| MCP-01 | `npx -y` sin version pin | HIGH |
| MCP-02 | `autoApprove: true` sin deny list | CRITICAL |
| MCP-03 | Hardcoded secret patterns en `env` | CRITICAL |
| MCP-04 | Transport `shell` sin sandbox | HIGH |
| MCP-05 | Remote endpoint (http/https) sin auth header | HIGH |
| MCP-06 | Args con shell metacharacters (`;`, `\|`, `` ` ``) | HIGH |
| MCP-07 | Args apuntando a `~/.ssh`, `~/.aws`, `~/.azure` | HIGH |
| MCP-08 | Server name con path traversal (`..`) | CRITICAL |
| MCP-09 | `command: "bash"`/`sh` sin whitelist | HIGH |
| MCP-10 | `env` expone `PATH` sobrescrito | MEDIUM |
| MCP-11 | Descripción/metadata ausente | LOW |

## Acceptance criteria

- Script ejecutable con `--help`, `--json`, exit codes 0/1/2
- Detecta 11 patrones arriba; tests BATS sintéticos para cada uno
- No requiere ejecutar MCPs — solo lee config
- Zero egress
- `set -uo pipefail`
- BATS suite ≥ 20 tests, score ≥ 80

## Referencias

- `output/research/agentshield-20260420.md` (inspiración, 23 reglas MCP)
- `.claude/mcp.json` (target actual)
- agentshield MIT: github.com/affaan-m/agentshield
