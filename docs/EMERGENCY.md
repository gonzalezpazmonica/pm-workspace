# Guía de Emergencia — PM-Workspace

> Qué hacer cuando Claude Code / el proveedor de LLM cloud no está disponible.

---

## Paso 0: Preparación preventiva (RECOMENDADO)

Ejecuta esto **ahora**, mientras tienes conexión, para que todo funcione offline:

```bash
cd ~/claude
./scripts/emergency-plan.sh
```

Esto pre-descarga el instalador de Ollama y el modelo LLM en caché local (~5-10GB). Si algún día pierdes conexión, `emergency-setup` usará la caché automáticamente. Se sugiere automáticamente la primera vez que arrancas pm-workspace en una máquina nueva.

## ¿Cuándo activar el modo emergencia?

Activa el modo emergencia si:
- Claude Code no responde o da errores de conexión
- El proveedor de LLM (Anthropic) tiene una caída de servicio
- No hay conexión a internet pero necesitas seguir trabajando
- Quieres probar pm-workspace sin depender del cloud

## Setup Rápido (5 minutos)

### Paso 1: Ejecutar el instalador

```bash
cd ~/claude
./scripts/emergency-setup.sh
```

El script detectará tu hardware y te guiará por:
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
- Agentes especializados (requieren Opus/Sonnet cloud)
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

## Volver a modo normal

Cuando el servicio cloud vuelva a estar disponible:

```bash
unset ANTHROPIC_BASE_URL
unset PM_EMERGENCY_MODE
unset PM_EMERGENCY_MODEL
```

O simplemente cierra y abre una nueva terminal.

## Troubleshooting

**"Ollama no instalado"**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

**"Servidor no responde"**
```bash
ollama serve &
```

**"Modelo no descargado"**
```bash
ollama pull qwen2.5:7b
```

**"Respuestas muy lentas"**
- Usa un modelo más pequeño: `ollama pull qwen2.5:3b`
- Cierra aplicaciones que consuman RAM
- Si tienes GPU NVIDIA: Ollama la usa automáticamente

**"Out of memory"**
- Baja a un modelo menor (`qwen2.5:1.5b`)
- Cierra el navegador y otras apps pesadas
- Considera añadir swap temporal

## Referencia Rápida

```
./scripts/emergency-plan.sh           # Pre-descarga preventiva (ejecutar con internet)
./scripts/emergency-setup.sh          # Instalación (online u offline con caché)
./scripts/emergency-status.sh         # Diagnóstico del sistema
./scripts/emergency-fallback.sh help  # Operaciones sin LLM
source ~/.pm-workspace-emergency.env  # Activar modo emergencia
```

---

*Parte de PM-Workspace · [README principal](../README.md)*
