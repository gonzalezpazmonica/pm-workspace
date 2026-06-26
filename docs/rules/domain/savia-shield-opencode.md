---
context_tier: L2
token_budget: 1800
resource: internal://docs/rules/domain/savia-shield-opencode.md
spec: SPEC-OC-01
---

# Savia Shield — OpenCode Adaptation

> Reference: SPEC-OC-01, docs/savia-shield.md, docs/rules/domain/data-sovereignty.md

## Qué es Savia Shield bajo OpenCode

Savia Shield es el sistema de 8 capas de protección de datos que opera en sesiones
de IA. Bajo Claude Code, las capas se ejecutan como bash hooks en .claude/hooks/.
Bajo OpenCode v1.14, las mismas protecciones se ejecutan como TypeScript guards
en .opencode/plugins/guards/ mediante los eventos tool.execute.before y
tool.execute.after del plugin savia-foundation.ts.

**Dual-stack (PV-01):** Los bash hooks siguen activos bajo Claude Code. Los TS
guards son aditivos bajo OpenCode. Sin regresión.

## Capas activas bajo OpenCode

| Capa | Guard TS | Descripción |
|------|----------|-------------|
| 1+8 | guards/data-sovereignty-gate.ts | Bloquea credenciales en ficheros N1. Base64 + NFKC. |
| 5 | guards/data-sovereignty-audit.ts | Post-edit audit logger. No bloquea. |
| 6 | guards/block-credential-leak.ts | Detecta tokens en comandos bash. |
| 6 | guards/block-force-push.ts | Bloquea push destructivo a main. |
| — | guards/block-gitignored-references.ts | Bloquea escrituras con rutas en .gitignore. |
| — | guards/prompt-injection-guard.ts | Escanea ficheros clasificados. |
| — | guards/validate-bash-global.ts | Regex ligero sobre comandos bash. |
| — | guards/tdd-gate.ts | Verifica existencia de tests. |
| A | .opencode/hooks/context-sanitize-input.sh | Sanitiza payloads de texto. |

## Qué datos protege

Clasificación N1-N4b según data-sovereignty.md:

- **N1 Público**: docs/, scripts/, tests/, CHANGELOG.md, README, plugins, hooks.
  Guards bloquean escritura de credenciales en N1.
- **N3 Privado**: output/, logs.
- **N4b PM-Only**: specs, configuración local, perfiles.

Destinos que los guards omiten (escritura libre):
projects/, tenants/, .savia/, output/, tests/fixtures/.

Tipos de dato bloqueados:
- Connection strings (JDBC, MongoDB SRV, SQL Server con password)
- AWS Access Keys (AKIA...)
- GitHub tokens (ghp_, github_pat_)
- API keys OpenAI y Anthropic (sk-, sk-ant-)
- Azure SAS tokens (sv=20XX-)
- Private keys PEM
- JWT tokens (eyJ.eyJ.signature)
- Kubernetes SA tokens
- IPs internas RFC 1918
- Credenciales base64-encoded (blobs 40+ chars)

## Activar Savia Shield en OpenCode

El shield se activa automáticamente al abrir OpenCode en el workspace.
El plugin savia-foundation.ts se carga y registra todos los guards.
No se requiere configuración manual.

### Variables de entorno

| Variable | Default | Efecto |
|----------|---------|--------|
| SAVIA_HARDENING | on | off desactiva context-sanitize-input.sh |
| SAVIA_SANITIZE_INPUT | warn | Modo: off, shadow, warn, block |
| SAVIA_WORKSPACE_DIR | git root | Fuerza el directorio de workspace |

## Verificar que está activo

```bash
bash scripts/savia-shield-check.sh        # texto legible
bash scripts/savia-shield-check.sh --json  # JSON para integración
```

Estados posibles:

| Estado | Significado | Exit code |
|--------|-------------|-----------|
| active | Todos los componentes encontrados | 0 |
| partial | Componentes no críticos ausentes | 1 |
| inactive | Componentes críticos ausentes | 2 |

## Diferencias respecto a Claude Code

| Aspecto | Claude Code | OpenCode |
|---------|-------------|----------|
| Mecanismo | Bash hooks en .claude/hooks/ | TS guards en .opencode/plugins/guards/ |
| Activación | settings.json hooks array | Plugin auto-cargado desde opencode.json |
| Daemon shield | Capas 2+4 en localhost | REMOVIDO — inline regex solamente |
| Env var principal | CLAUDE_PROJECT_DIR | SAVIA_WORKSPACE_DIR |

## Diagnóstico

**Guards no se ejecutan:** Ejecutar `cd .opencode/plugins && bun install`.

**shield_status inactive:** Ejecutar savia-shield-check.sh para identificar
el componente faltante y restaurar desde git.

**Falso positivo bloqueado:** El guard data-sovereignty-gate.ts tiene allowlist
SH01 para ficheros de script: tokens de código se downgradean de BLOCK a WARN.

## Referencias

- docs/savia-shield.md — arquitectura completa (8 capas)
- docs/rules/domain/data-sovereignty.md — política de soberanía N1-N4b
- .opencode/plugins/README.md — estructura del plugin
- scripts/savia-env.sh — capa de entorno provider-agnostic
- SPEC-OC-01 — spec de esta adaptación
