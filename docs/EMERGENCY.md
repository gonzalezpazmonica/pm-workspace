# Guía de Emergencia — PM-Workspace

> Qué hacer cuando Claude Code / el proveedor de LLM cloud no está disponible.

---

## Paso 0: Preparación preventiva (RECOMENDADO)

Ejecuta esto **ahora**, mientras tienes conexión, para que todo funcione offline:

```bash
# Linux / macOS
cd ~/claude
./scripts/emergency-plan.sh

# Windows (PowerShell)
cd ~\claude
.\scripts\emergency-plan.ps1
```

Esto pre-descarga el instalador de Ollama y el modelo LLM en caché local (~5-10GB). Soporta Linux (amd64/arm64), macOS (Intel/Apple Silicon) y Windows. El script ejecuta 5 pasos: verificar conectividad, detectar hardware, descargar Ollama, descargar modelo(s) LLM, y verificar caché offline. Es idempotente — re-ejecutar omite lo que ya está cacheado. Si algún día pierdes conexión, `emergency-setup` usará la caché automáticamente. Se sugiere automáticamente la primera vez que arrancas pm-workspace en una máquina nueva.

## ¿Cuándo activar el modo emergencia?

Activa el modo emergencia si:
- Claude Code no responde o da errores de conexión
- El proveedor de LLM (Anthropic) tiene una caída de servicio
- No hay conexión a internet pero necesitas seguir trabajando
- Quieres probar pm-workspace sin depender del cloud

## Setup Rápido (5 minutos)

### Paso 1: Ejecutar el instalador

```bash
# Linux / macOS
cd ~/claude
./scripts/emergency-setup.sh

# Windows (PowerShell)
cd ~\claude
.\scripts\emergency-setup.ps1
```

El script detectará automáticamente tu SO y hardware, y te guiará por:
1. Instalación de Ollama (gestor de LLMs locales)
2. Descarga del modelo recomendado para tu RAM
3. Configuración automática de variables

Si no hay internet, usará la caché local de `emergency-plan` automáticamente.

Si tu equipo tiene **menos de 16GB de RAM**, usa un modelo más pequeño:
```bash
./scripts/emergency-setup.sh --model qwen2.5:3b
```

### Paso 2: Verificar que funciona

```bash
./scripts/emergency-status.sh
```

Deberías ver todo en verde (✓). Si hay problemas, el script te dice qué hacer.

### Paso 3: Activar el modo emergencia

```bash
source ~/.pm-workspace-emergency.env
```

Ahora Claude Code usará el LLM local en lugar del cloud.

## Qué puedes hacer en modo emergencia

### Con LLM local (capacidad ~70%)
- Revisar y generar código
- Crear documentación
- Analizar bugs y proponer fixes
- Sprint planning básico
- Code review asistido

### Sin LLM (scripts offline)
```bash
./scripts/emergency-fallback.sh git-summary      # Actividad git reciente
./scripts/emergency-fallback.sh board-snapshot    # Exportar estado del board
./scripts/emergency-fallback.sh team-checklist    # Checklists daily/review/retro
./scripts/emergency-fallback.sh pr-list           # PRs pendientes
./scripts/emergency-fallback.sh branch-status     # Ramas activas
```

### Qué NO funciona bien en emergencia
- Agentes especializados (calidad reducida con modelos locales)
- Generación de informes complejos (Excel/PowerPoint)
- Operaciones con Azure DevOps API (si no hay internet)
- Contexto >32K tokens (modelos locales tienen ventana limitada)

## Hardware Mínimo Recomendado

| RAM | Modelo recomendado | Capacidad |
|-----|-------------------|-----------|
| 8GB | qwen2.5:3b | Básica — coding simple, Q&A |
| 16GB | qwen2.5:7b | Buena — coding, review, docs |
| 32GB | qwen2.5:14b | Muy buena — casi como cloud |
| GPU NVIDIA | deepseek-coder-v2 | Excelente — con aceleración GPU |

## Mapeo de Modelos

Los aliases `opus`/`sonnet`/`haiku` de los 27 agentes se resuelven a modelos locales según RAM: 8GB→`3b` para todos · 16GB→`7b`/`7b`/`3b` · 32GB+→`14b`/`7b`/`3b`. Variables oficiales de Claude Code: `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` y `CLAUDE_CODE_SUBAGENT_MODEL`. Personalízalas en `~/.pm-workspace-emergency.env`. Para usuarios de [Claude Code Router](https://github.com/musistudio/claude-code-router) (proyecto comunitario): tag `CCR-SUBAGENT-MODEL` permite override por agente.

## Volver a modo normal

Cuando el servicio cloud vuelva a estar disponible:

```bash
unset ANTHROPIC_BASE_URL PM_EMERGENCY_MODE PM_EMERGENCY_MODEL
unset ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL
unset ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_SUBAGENT_MODEL
```

O simplemente cierra y abre una nueva terminal.

## Troubleshooting

**"Ollama no instalado"** → Linux: `curl -fsSL https://ollama.ai/install.sh | sh` · macOS: re-ejecuta `emergency-setup.sh` · Windows: ejecuta `OllamaSetup.exe` desde la caché.

**"Servidor no responde"** → `ollama serve &`

**"Modelo no descargado"** → `ollama pull qwen2.5:7b`

**"Respuestas lentas"** → Usa modelo menor (`qwen2.5:3b`), cierra apps que consuman RAM, GPU NVIDIA se usa automáticamente.

**"Out of memory"** → Baja a `qwen2.5:1.5b`, cierra navegador, considera swap temporal.

## Referencia Rápida

```
# Linux / macOS                         # Windows (PowerShell)
./scripts/emergency-plan.sh             .\scripts\emergency-plan.ps1
./scripts/emergency-setup.sh            .\scripts\emergency-setup.ps1
./scripts/emergency-status.sh           (revisar Ollama manualmente)
./scripts/emergency-fallback.sh help    (usar Git Bash)
source ~/.pm-workspace-emergency.env    (variables configuradas automáticamente)
```

---

*Parte de PM-Workspace · [README principal](../README.md)*
