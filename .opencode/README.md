# PM-Workspace con OpenCode

OpenCode es el **frontend primario** de PM-Workspace (Savia). Este documento describe la estructura y el funcionamiento nativo en OpenCode.

> ¿Buscas el frontend alternativo? Claude Code sigue siendo compatible — ver [`../.claude/`](../.claude/) y [`../CLAUDE.md`](../CLAUDE.md).

## Estructura

```
.opencode/
├── agents/          # Catalogo de agentes especializados
├── commands/        # Comandos slash (/sprint-status, /pr-plan, etc.)
├── skills/          # Skills cargables bajo demanda
├── hooks/           # Hooks deterministas (PreToolUse, PostToolUse, Stop, etc.)
├── plugins/         # Plugins TypeScript (~25 eventos)
├── profiles/        # Perfiles de usuario activos
└── settings.json    # Configuracion de hooks y permisos
```

OpenCode lee directamente esta estructura sin requerir adaptaciones. Los comandos slash, agentes y skills se invocan de forma nativa.

## Uso rapido

### Instalacion

Linux/macOS:
```bash
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh | bash
cd ~/savia && opencode
```

Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex
```

El instalador (`install.sh` / `install.ps1`) configura OpenCode por defecto. Anade `--with-claude-code` si quieres ambos frontends.

### Primera sesion

```bash
cd ~/savia
opencode
```

Savia te saluda, te pregunta el perfil y queda lista para operar. Despues:

```
/help                    # catalogo interactivo
/sprint-status           # estado del sprint actual
/spec-generate           # convierte una task en spec ejecutable
```

## Configuracion necesaria

### Azure DevOps (opcional)
```bash
# Crear PAT en https://dev.azure.com/<ORG>/_usersSettings/tokens
echo "TU_PAT" > ~/.azure/devops-pat
```

### Azure CLI (opcional)
```bash
az devops configure --defaults organization=https://dev.azure.com/TU_ORG
export AZURE_DEVOPS_EXT_PAT=$(cat ~/.azure/devops-pat)
```

### Dependencias scripts
```bash
cd ~/savia/scripts && npm install
```

## Hooks y seguridad

OpenCode ejecuta hooks nativos definidos en `.opencode/settings.json`:

- **PreToolUse**: validacion bash, prevencion de credenciales hardcodeadas, gate de specs SDD
- **PostToolUse**: audit logging, AST quality gate, post-edit checks
- **Stop**: regeneracion automatica de catalogos (AGENTS.md, SKILLS.md)
- **SessionStart**: carga de identidad Savia, contexto de proyecto activo

Los hooks bash en `.opencode/hooks/*.sh` se invocan automaticamente. Los plugins TypeScript en `.opencode/plugins/` cubren eventos adicionales.

## Skills

Los skills se cargan bajo demanda. Listado completo en `SKILLS.md` y `.opencode/skills/`. Ejemplos:

- `azure-devops-queries` — consultas WIQL
- `pbi-decomposition` — descomposicion de PBIs en tasks
- `spec-driven-development` — SDD con specs ejecutables
- `sprint-management` — gestion completa de sprints
- `savia-shield` — clasificacion local de datos

## Tests

```bash
cd ~/savia
bash scripts/test-workspace.sh --mock   # suite completa modo mock
bash tests/run-all.sh                   # tests BATS de hooks
```

## Solucion de problemas

### "No se encuentra el PAT"
```bash
echo "TU_PAT" > ~/.azure/devops-pat
chmod 600 ~/.azure/devops-pat
```

### "Comando opencode no encontrado"
Reinstala OpenCode: `curl -fsSL https://opencode.ai/install | bash`. Verifica con `opencode --version`.

### "Comando az no encontrado"
Instala Azure CLI o usa modo `--mock` en los tests.

## Compatibilidad con Claude Code

PM-Workspace mantiene 73 agentes y 532 comandos en `.claude/` como frontend alternativo. Si tienes ambos frontends:

- OpenCode lee `.opencode/`
- Claude Code lee `.claude/`
- Ambos comparten `projects/`, `scripts/`, `docs/`, memoria persistente

Para activar Claude Code en un workspace ya instalado:
```bash
bash scripts/setup-claude-permissions.sh
```

## Licencia

PM-Workspace es open-source (MIT). Desarrollado por [la usuaria González Paz](https://github.com/gonzalezpazmonica).

Documentacion completa: [README principal](../README.md) | [Guia de instalacion](../docs/install/opencode-quick-install.md) | [Getting started](../docs/getting-started.md)
