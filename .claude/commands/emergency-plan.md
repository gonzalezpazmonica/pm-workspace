---
name: emergency-plan
description: Pre-descargar Ollama y modelo LLM en caché local para instalación offline
developer_type: all
agent: none
context_cost: low
---

# /emergency-plan [--model MODEL]

> Pre-descarga todos los recursos necesarios para que `/emergency-mode setup` funcione sin conexión a internet.

---

## ¿Por qué?

Si el proveedor cloud de LLM cae y además no hay internet, `/emergency-mode setup` no podrá descargar Ollama ni el modelo. Con `/emergency-plan` ejecutado previamente, todo queda cacheado en local.

## Prerequisitos

- Conexión a internet (para la descarga inicial)
- ~5-10GB de espacio libre (según modelo)

## Qué descarga

1. **Script de instalación de Ollama** — `~/.pm-workspace-emergency/ollama-install.sh`
2. **Binario de Ollama** — `~/.pm-workspace-emergency/ollama-{os}-{arch}`
3. **Modelo LLM** — cacheado en Ollama o en directorio local

## Selección automática de modelo

Si no se especifica `--model`, se selecciona según la RAM disponible:

| RAM | Modelo | Tamaño descarga |
|-----|--------|----------------|
| <16GB | qwen2.5:3b | ~2GB |
| 16-31GB | qwen2.5:7b | ~4.4GB |
| ≥32GB | qwen2.5:14b | ~9GB |

## Uso

```bash
# Descarga automática según hardware
./scripts/emergency-plan.sh

# Con modelo específico
./scripts/emergency-plan.sh --model mistral:7b

# Verificar si ya se ejecutó
./scripts/emergency-plan.sh --check
```

## Verificación

El script crea un marcador en `~/.pm-workspace-emergency/.plan-executed`.
- `--check` retorna exit code 0 si ya se ejecutó, 1 si no
- `session-init.sh` verifica este marcador y recuerda ejecutar el plan

## Integración con emergency-setup

Cuando `emergency-setup.sh` detecta que no hay internet:
1. Busca el binario de Ollama en la caché local
2. Lo instala desde el fichero local
3. El modelo ya está cacheado por Ollama (descargado durante plan)
4. Setup completo sin necesidad de internet

## Sugerencia automática

La primera vez que se inicia Claude Code en una máquina nueva, `session-init.sh` verifica si el emergency plan se ha ejecutado. Si no, muestra un recordatorio para que el usuario lo ejecute.

## Caché local

Todo se almacena en `~/.pm-workspace-emergency/`:
```
~/.pm-workspace-emergency/
├── .plan-executed          # Marcador de ejecución con timestamp
├── plan-info.json          # Metadata (OS, RAM, modelo elegido)
├── ollama-install.sh       # Script de instalación
└── ollama-linux-x86_64     # Binario (Linux)
```

Los modelos de Ollama se cachean en `~/.ollama/models/` (directorio estándar de Ollama).
