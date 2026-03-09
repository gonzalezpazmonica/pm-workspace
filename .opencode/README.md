# PM‑Workspace con OpenCode

Este documento explica cómo usar PM‑Workspace (Savia) con **OpenCode** en lugar de Claude Code. PM‑Workspace es un entorno completo de gestión de proyectos automatizada con IA, originalmente diseñado para Claude Code, pero adaptado para funcionar con OpenCode.

## 🔄 ¿Qué cambia con OpenCode?

| Aspecto | Claude Code | OpenCode |
|---------|-------------|----------|
| **Interfaz principal** | CLI `claude` | CLI `opencode` |
| **Comandos slash** | Ejecutados automáticamente | Se siguen manualmente (leer `.md` y usar tools) |
| **Skills** | Cargados automáticamente | Se cargan con `/skill <nombre>` |
| **Hooks automáticos** | Sí (session‑init, pre‑edit, etc.) | No se ejecutan automáticamente |
| **Agentes (Task tool)** | Sí | Sí (misma funcionalidad) |
| **Integración Azure DevOps** | Completa | Completa (requiere PAT y `az`) |
| **Variables de entorno** | Auto‑cargadas | Cargar con `source .opencode/init‑pm.sh` |

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
OpenCode no ejecuta hooks automáticamente. La lógica de validación está en los scripts (`.claude/hooks/`) y puedes ejecutarlos manualmente si es necesario.

## 📄 Licencia y créditos

PM‑Workspace es open‑source (MIT). Desarrollado por Mónica González Paz.

Para la versión completa con Claude Code, consulta el [README principal](../README.md).

---

**Nota**: Esta adaptación mantiene el 100% de la funcionalidad de PM‑Workspace. La única diferencia es la interfaz (OpenCode vs Claude Code), no las capacidades de gestión de proyectos.