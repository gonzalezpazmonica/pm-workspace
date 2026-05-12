# OpenCode Quick Install

> Guía rápida de instalación de OpenCode como frontend primario de Savia.
> Claude Code es un frontend alternativo soportado — ver `--with-claude-code` abajo.

OpenCode es el frontend recomendado para Savia: open-source, multi-provider,
sin vendor lock-in. Soporta plugins TypeScript nativos para los 5 hooks
Tier-1 de seguridad. Claude Code sigue funcionando como alternativa.

## TL;DR

```bash
# Linux / macOS / WSL
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/savia
cd ~/savia
./install.sh
```

```powershell
# Windows (recomendado: WSL2 + comandos de arriba)
git clone https://github.com/gonzalezpazmonica/pm-workspace.git $HOME\savia
cd $HOME\savia
.\install.ps1
```

El instalador descarga OpenCode, clona el repo, ejecuta onboarding y deja
Savia operativa en `~/savia` (Linux/macOS) o `$HOME\savia` (Windows).

## Prerrequisitos

| Componente | Versión mínima | Notas |
|---|---|---|
| git | 2.30+ | Necesario para clonar el repo |
| bash | 4.0+ | macOS: instalar bash 5 vía Homebrew |
| Python | 3.10+ | Para hooks de seguridad y skills |
| Node.js | 18+ (opcional) | Solo si usas `npm` como gestor para OpenCode |

Windows nativo requiere PowerShell 5.1+. Recomendado: WSL2 con Ubuntu 22.04
para paridad completa con la plataforma de desarrollo de Savia.

## Instaladores

### Linux / macOS / WSL — `install.sh`

```bash
./install.sh                      # OpenCode + Savia (default)
./install.sh --with-claude-code   # Ambos frontends
./install.sh --skip-opencode      # Solo Savia, sin instalar OpenCode
./install.sh --skip-tests         # Saltar validación post-install
SAVIA_HOME=/custom/path ./install.sh   # Instalar en ruta personalizada
```

El script:
1. Detecta sistema operativo y gestor de paquetes.
2. Instala OpenCode vía `brew` (macOS), gestor del sistema (Linux) o `npm install -g opencode-ai`.
3. Clona o actualiza el repo en `$SAVIA_HOME` (default `~/savia`).
4. Migra `~/claude` a `~/savia` si existe (con confirmación).
5. Instala dependencias Python (`pip install -r requirements.txt`).
6. Ejecuta `bash scripts/savia-bootstrap.sh` para configurar el workspace.
7. Lanza onboarding interactivo.
8. Valida instalación con tests básicos (omitir con `--skip-tests`).

### Windows — `install.ps1`

```powershell
.\install.ps1                       # OpenCode + Savia (default)
.\install.ps1 -WithClaudeCode       # Ambos frontends
.\install.ps1 -SkipOpenCode         # Solo Savia
.\install.ps1 -SkipTests            # Saltar tests
.\install.ps1 -ForceNative          # Saltar prompt WSL
$env:SAVIA_HOME="C:\custom"; .\install.ps1
```

Orden de gestores Windows: **Scoop > Chocolatey > winget > npm**.
Si ninguno está disponible, el script ofrece instalar Scoop automáticamente.

Por defecto, el script detecta Windows nativo y recomienda usar WSL2.
Para forzar instalación nativa, usar `-ForceNative` o `$env:FORCE_NATIVE=1`.

## WSL2 (recomendado en Windows)

WSL2 da paridad completa con Linux y evita problemas de path/encoding.

### Instalar WSL2 + Ubuntu

```powershell
# PowerShell como administrador
wsl --install -d Ubuntu-22.04
# Reiniciar Windows cuando lo pida
```

Tras el reinicio, Ubuntu lanza un wizard para crear usuario. Una vez dentro:

```bash
# Dentro de Ubuntu WSL
sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3 python3-pip build-essential
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/savia
cd ~/savia
./install.sh
```

### Acceder a Savia desde Windows

Los ficheros de WSL son accesibles desde Windows en `\\wsl$\Ubuntu-22.04\home\<usuario>\savia`.
Para abrir el workspace desde VS Code Windows: `code .` dentro de WSL — VS Code
detecta WSL y abre la extensión `Remote - WSL` automáticamente.

## Migración desde `~/claude`

Si tenías Savia instalada en `~/claude` (versiones anteriores), el instalador
detecta la ruta y ofrece migrar:

```text
[migrate] Detected existing installation at ~/claude
[migrate] Move to ~/savia? [Y/n]
```

Acepta (`Y`) para mover el directorio. El instalador preserva ramas, worktrees
y configuración local (`.claude/settings.local.json`, `pm-config.local.md`).

## Activar OpenCode tras instalar

```bash
cd ~/savia
opencode    # Lanza OpenCode con el workspace cargado
```

OpenCode detecta automáticamente `.opencode/` y carga 92 skills, 73 agents
y 532 commands disponibles.

## Activar Claude Code (alternativa)

Si instalaste con `--with-claude-code`:

```bash
cd ~/savia
claude     # Lanza Claude Code con el workspace cargado
```

Claude Code lee `.claude/settings.json` y carga los mismos skills/agents/commands.

## Troubleshooting

### "opencode: command not found" tras instalar

```bash
# Verificar PATH
echo $PATH | tr ':' '\n' | grep -E 'opencode|.local/bin|.npm-global'

# Linux/macOS — añadir ~/.local/bin al PATH si falta
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

```powershell
# Windows — el instalador añade $HOME\.local\bin al PATH usuario
# Si no funciona, reabrir la terminal o reiniciar sesión Windows
```

### "Permission denied" al ejecutar `install.sh`

```bash
chmod +x install.sh
./install.sh
```

### Tests fallan en post-install

```bash
# Re-ejecutar tests manualmente para ver detalles
bash tests/validate-install.sh

# Saltar tests si bloquean uso urgente
./install.sh --skip-tests
```

### OpenCode arranca pero no encuentra skills/agents

OpenCode debe ejecutarse desde la raíz del workspace:

```bash
cd ~/savia    # NO desde subdirectorio
opencode
```

### Conflicto entre instalación previa y nueva

```bash
# Backup de configuración local antes de reinstalar
cp .claude/settings.local.json ~/savia-settings-backup.json
cp .claude/rules/pm-config.local.md ~/savia-pm-config-backup.md

# Reinstalar con SAVIA_HOME limpio
rm -rf ~/savia
./install.sh

# Restaurar config local
cp ~/savia-settings-backup.json ~/savia/.claude/settings.local.json
cp ~/savia-pm-config-backup.md ~/savia/.claude/rules/pm-config.local.md
```

## Siguiente paso

Tras instalar, lee la guía de onboarding que corresponda a tu rol:

- **PM**: `docs/quick-starts/quick-start-pm.md`
- **Developer**: `docs/quick-starts/quick-start-developer.md`
- **QA**: `docs/quick-starts/quick-start-qa.md`
- **Tech Lead**: `docs/quick-starts/quick-start-tech-lead.md`
- **CEO / PO**: `docs/quick-starts/quick-start-ceo.md` o `quick-start-po.md`
- **Enterprise**: `docs/getting-started/enterprise.md`
- **Community**: `docs/getting-started/community.md`

## Referencias

- `install.sh` — instalador Linux/macOS/WSL (raíz del repo)
- `install.ps1` — instalador Windows (raíz del repo)
- `.opencode/README.md` — arquitectura OpenCode-native
- `.opencode/hooks/README.md` — 65 hooks de seguridad
- `.opencode/plugins/README.md` — ports TypeScript Tier-1
- OpenCode docs: <https://opencode.ai/docs>
