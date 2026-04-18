# PM‑Workspace con OpenCode

Este documento explica cómo usar PM‑Workspace (Savia) con **OpenCode** en lugar de Claude Code. PM‑Workspace es un entorno completo de gestión de proyectos automatizada con IA, originalmente diseñado para Claude Code, pero adaptado para funcionar con OpenCode.

## 🔄 ¿Qué cambia con OpenCode?

| Aspecto | Claude Code | OpenCode |
|---------|-------------|----------|
| **Interfaz principal** | CLI `claude` | CLI `opencode` |
| **Comandos slash** | Ejecutados automáticamente | Se siguen manualmente (leer `.md` y usar tools) |
| **Skills** | Cargados automáticamente | Se cargan con `/skill <nombre>` |
| **Hooks automáticos** | Sí (session‑init, pre‑edit, etc.) | No se ejecutan automáticamente* |
| **Agentes (Task tool)** | Sí | Sí (misma funcionalidad) |
| **Integración Azure DevOps** | Completa | Completa (requiere PAT y `az`) |
| **Variables de entorno** | Auto‑cargadas | Cargar con `source .opencode/init‑pm.sh` |


*^Se proveen Git hooks y wrappers como alternativa; ver sección **🔒 Seguridad y calidad con hooks**.*

## 🚀 Uso rápido

### Instalación (Linux/macOS)
```bash
curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/.opencode/install.sh | bash
```

### Instalación (Windows PowerShell)
```powershell
irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/.opencode/install.ps1 | iex
```

### Configuración manual
1. **Clonar e instalar** (ver instaladores arriba)
2. **Inicializar entorno PM**:
   ```bash
   cd ~/claude/.opencode
   source init‑pm.sh
   ```
3. **Abrir OpenCode**:
   ```bash
   opencode
   ```
4. **Cargar un skill**:
   ```bash
   /skill azure‑devops‑queries
   /skill pbi‑decomposition
   /skill spec‑driven‑development
   ```
5. **Seguir flujos manualmente**:
   - Los comandos slash (400+) están en `.claude/commands/`
   - Lee el `.md` correspondiente y ejecuta sus pasos con las herramientas de OpenCode (Bash, Read, Grep, Task, etc.)

## 📁 Estructura del directorio `.opencode`

```
.opencode/
├── .claude/                 # Enlace simbólico al directorio original
├── CLAUDE.md                # Configuración global (copia)
├── CLAUDE.local.md          # Configuración privada (copia)
├── init‑pm.sh               # Script para cargar variables de entorno PM
├── docs/ → symlink          # Documentación
├── projects/ → symlink      # Proyectos
├── scripts/ → symlink       # Scripts de utilidad
├── run‑all‑tests.sh         # Ejecuta todos los tests
└── README.md                # Este archivo
```

## ⚙️ Configuración necesaria

### 1. Azure DevOps (opcional)
```bash
# Crear PAT en https://dev.azure.com/*/_usersSettings/tokens
# Guardar en ~/.azure/devops‑pat (una línea, sin salto)
echo "TU_PAT_AQUI" > ~/.azure/devops‑pat
```

### 2. Azure CLI (opcional, para operaciones avanzadas)
```bash
# Instalar
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Configurar
az devops configure --defaults organization=https://dev.azure.com/TU_ORG
export AZURE_DEVOPS_EXT_PAT=$(cat ~/.azure/devops‑pat)
```

### 3. Dependencias Node.js
```bash
cd ~/claude/scripts && npm install
```

## 🧪 Ejecutar tests

```bash
cd ~/claude/.opencode
bash run‑all‑tests.sh        # Ejecuta todos los scripts test-*.sh
```

Para tests individuales:
```bash
cd ~/claude
bash scripts/test‑workspace.sh --mock      # Suite completa (modo mock)
bash tests/run‑all.sh                      # Tests BATS (hooks)
```

## 🔧 Skills disponibles (43)

Carga cualquier skill con `/skill <nombre>`:

- `azure‑devops‑queries` – Consultas a Azure DevOps
- `pbi‑decomposition` – Descomposición de PBIs en tasks
- `spec‑driven‑development` – SDD con specs ejecutables
- `sprint‑management` – Gestión completa de sprints
- `capacity‑planning` – Cálculo de capacidades del equipo
- `time‑tracking‑report` – Informes de imputación de horas
- `executive‑reporting` – Informes ejecutivos
- `product‑discovery` – Descubrimiento de producto (JTBD/PRD)
- `diagram‑generation` – Generación de diagramas
- … y 34 más (ver `.claude/skills/`)

## 📚 Cómo usar un comando slash manualmente

Ejemplo: **`/sprint‑status sala‑reservas`**

1. **Leer el comando**:
   ```bash
   read ~/claude/.claude/commands/sprint‑status.md
   ```
2. **Seguir sus instrucciones** (generalmente):
   - Cargar skill `azure‑devops‑queries`
   - Ejecutar queries WIQL con `bash` o `curl`
   - Analizar resultados con `jq`, `grep`
   - Generar informe

3. **Ejecutar paso a paso** con las herramientas de OpenCode.

## 🐛 Solución de problemas

### “No se encuentra el PAT”
```bash
export AZURE_DEVOPS_PAT_FILE="$HOME/.azure/devops‑pat"
source ~/claude/.opencode/init‑pm.sh
```

### “Comando az no encontrado”
Instalar Azure CLI o usar modo `--mock` en los tests.

### “Error al cargar skill”
Verificar que el enlace `.claude/` existe:
```bash
ls -la ~/claude/.opencode/.claude
```

### “Los hooks no se ejecutan”
OpenCode no ejecuta hooks automáticamente. Hemos implementado dos soluciones para mantener la seguridad y calidad:

1. **Git hooks automáticos** (recomendado) — validan commits y pushes.
2. **Wrappers para herramientas** — validan comandos bash, ediciones y tareas antes de ejecutarlas.

Consulta la sección **🔒 Seguridad y calidad con hooks** más abajo.

## 🔒 Seguridad y calidad con hooks

### 🧠 ¿Qué son los hooks y por qué importan?
Los hooks en PM‑Workspace son **salvaguardas programáticas no eludibles** que garantizan:
- **Seguridad**: Detectan secretos hardcodeados, bloquean comandos destructivos (`rm -rf /`, `terraform destroy`) y previenen force‑push.
- **Calidad**: Exigen specs aprobadas antes de implementar, verifican tests (TDD) y revisan código automáticamente.
- **Consistencia**: Aseguran que los mensajes de commit sigan convenciones y que los agentes reciban prompts bien formados.

En Claude Code, estos hooks se ejecutan automáticamente gracias al archivo `.claude/settings.json`. OpenCode **no interpreta** ese archivo, por lo que las protecciones quedarían desactivadas. Para resolverlo, hemos creado dos capas que **no interfieren con Claude Code**.

### 🔧 Diseño de la solución (dos capas independientes)

#### Capa 1: Git hooks automáticos
**Ubicación**: Scripts instalados en `.git/hooks/` (solo en tu repositorio local).  
**Invocación**: Git ejecuta estos hooks automáticamente al hacer `git commit`, `git push`, etc.  
**Ventaja**: No requiere cambios en tu flujo de trabajo; la protección está siempre activa.

```bash
# Instalar (una vez)
cd ~/claude/.opencode
bash scripts/install‑git‑hooks.sh
```

Se instalan tres hooks:
- **pre‑commit**: Ejecuta `pre‑commit‑review.sh` (revisión de código) y `stop‑quality‑gate.sh` (detección de secrets en cambios staged).
- **pre‑push**: Ejecuta `block‑force‑push.sh` mediante `run‑hook.sh` (bloquea `git push --force` y pushes directos a main).
- **commit‑msg**: Ejecuta `prompt‑hook‑commit.sh` (valida el formato del mensaje de commit).

**Desinstalación**: Elimina los ficheros `pre‑commit`, `pre‑push` y `commit‑msg` del directorio `.git/hooks/` o restaura los backups creados durante la instalación.

#### Capa 2: Wrappers para herramientas de OpenCode
**Ubicación**: `.opencode/scripts/opencode‑hooks/wrappers/`.  
**Invocación**: Tú llamas explícitamente a estos wrappers antes de usar las herramientas nativas de OpenCode.  
**Ventaja**: Extiende la validación a comandos bash generales, ediciones, escrituras y tareas.

| Herramienta | Wrapper | Validación realizada |
|-------------|---------|----------------------|
| `bash` | `safe‑bash.sh` | `validate‑bash‑global.sh` (comandos peligrosos), `block‑credential‑leak.sh` (secrets), `block‑infra‑destructive.sh` (infra destructiva). |
| `Edit` / `Write` | `safe‑edit.sh` / `safe‑write.sh` | `plan‑gate.sh` (warning si falta spec), `tdd‑gate.sh` (bloquea si no hay tests para código de producción). |
| `Task` | `safe‑task.sh` | `agent‑dispatch‑validate.sh` (valida que el prompt cumpla convenciones). |

**Ejemplo de uso**:
```bash
# En lugar de: bash "git commit -m 'test'"
bash .opencode/scripts/opencode‑hooks/wrappers/safe‑bash.sh "git commit -m 'test'"

# Antes de editar con OpenCode (luego usas la herramienta Edit)
bash .opencode/scripts/opencode‑hooks/wrappers/safe‑edit.sh src/app.js
```

### 🛡️ Por qué NO afecta al funcionamiento de Claude Code
1. **Ubicación aislada**: Todos los scripts (`install‑git‑hooks.sh`, `run‑hook.sh`, wrappers) están dentro de `.opencode/`, que **Claude Code ignora por completo**. Claude Code solo lee `.claude/` y los archivos de configuración en la raíz del proyecto.

2. **Git hooks locales**: Los hooks instalados en `.git/hooks/` son específicos de tu repositorio local. Claude Code **no lee ni depende** de esos hooks; su sistema de hooks propio se basa exclusivamente en `.claude/settings.json`.

3. **Wrappers opcionales**: Los wrappers **no reemplazan** las herramientas de OpenCode; son scripts auxiliares que tú invocas voluntariamente. Si no los usas, OpenCode funciona igual, solo que sin validaciones adicionales.

4. **Hooks originales intactos**: Los scripts de hooks originales (en `.claude/hooks/`) **no se modifican**. Claude Code los sigue ejecutando automáticamente cuando corresponde. Los wrappers y Git hooks simplemente **los reutilizan** pasándoles el JSON esperado.

5. **Separación de responsabilidades**: La adaptación para OpenCode **no toca** ningún archivo que Claude Code utilice. Es una capa adicional que se activa solo cuando trabajas con OpenCode.

### 📋 Recomendaciones de uso
1. **Instala los Git hooks** nada más configurar el entorno. Así tendrás protección automática en commits y pushes.
2. **Usa los wrappers** cuando ejecutes comandos bash delicados o edites código de producción. Para operaciones rutinarias (listar archivos, leer) puedes seguir usando las herramientas nativas.
3. **Si prefieres no usar wrappers**, al menos los Git hooks te cubrirán las operaciones más críticas (commit/push).

### 🔍 Validación manual de hooks
Puedes probar cualquier hook manualmente con el script `run‑hook.sh`:

```bash
# Simula un comando bash peligroso
bash .opencode/scripts/opencode‑hooks/run‑hook.sh validate‑bash‑global Bash "rm -rf /"

# Verifica si un archivo de código tiene tests
bash .opencode/scripts/opencode‑hooks/run‑hook.sh tdd‑gate Edit src/app.js
```

Esto es útil para depurar o entender qué bloquea cada hook.

## 📄 Licencia y créditos

PM‑Workspace es open‑source (MIT). Desarrollado por la usuaria González Paz.

Para la versión completa con Claude Code, consulta el [README principal](../README.md).

---

**Nota**: Esta adaptación mantiene el 100% de la funcionalidad de PM‑Workspace. La única diferencia es la interfaz (OpenCode vs Claude Code), no las capacidades de gestión de proyectos.