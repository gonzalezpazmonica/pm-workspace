# Emergency Watchdog

> Version: v4.5 | Era: 174 | Desde: 2026-04-03

## Que es

Servicio systemd que monitoriza la conectividad con api.anthropic.com cada 5 minutos. Tras 3 fallos consecutivos, activa automaticamente un LLM local via Ollama para que pm-workspace siga funcionando sin internet. Cuando la conexion vuelve, descarga el modelo para liberar RAM.

## Instalacion

```bash
# Instalar el servicio (requiere sudo)
sudo bash scripts/install-watchdog.sh

# Verificar estado
systemctl --user status savia-watchdog
```

Requisitos previos:
- Ollama instalado: `ollama --version`
- Al menos un modelo descargado: `ollama pull qwen2.5:3b`
- systemd disponible (Linux)

## Modelos soportados

| Hardware | Modelo recomendado | RAM usada |
|----------|-------------------|-----------|
| 8GB RAM | qwen2.5:3b | ~4GB |
| 16GB RAM | gemma4:e2b | ~8GB |
| 32GB+ RAM | gemma4:e4b | ~16GB |

## Uso basico

El watchdog opera de forma autonoma. No requiere intervencion manual.

```bash
# Ver logs en tiempo real
journalctl --user -u savia-watchdog -f

# Forzar chequeo inmediato
systemctl --user restart savia-watchdog
```

Durante una caida de internet, el log muestra:
```
[WATCHDOG] 3 fallos consecutivos — activando LLM local
[OLLAMA] Modelo cargado: qwen2.5:3b
```

## Configuracion

El script `scripts/savia-watchdog.sh` define las constantes:
- `CHECK_URL`: endpoint a monitorizar (api.anthropic.com)
- `CHECK_INTERVAL`: frecuencia en segundos (300 = 5 min)
- `MAX_FAILURES`: fallos antes de activar fallback (3)
- `FALLBACK_MODEL`: modelo Ollama a cargar

El modelo por defecto se selecciona segun la RAM disponible via `scripts/emergency-plan.sh`.

## Integracion

- **Savia Shield**: cuando el watchdog activa Ollama, `ollama-classify.sh` usa el modelo local para clasificacion de datos (Capa 2)
- **emergency-plan.sh**: script complementario que evalua la situacion y selecciona el modelo optimo
- **session-init.sh**: informa del estado del watchdog al inicio de sesion

## Troubleshooting

**Ollama no arranca**: verificar que el servicio Ollama esta activo: `systemctl status ollama`

**Modelo no se descarga**: ejecutar `ollama pull qwen2.5:3b` manualmente antes de instalar el watchdog

**El watchdog no detecta la caida**: revisar que `curl -s api.anthropic.com` falla (puede ser un problema de DNS local)

**RAM insuficiente**: usar el modelo mas ligero (qwen2.5:3b, ~4GB) o cerrar aplicaciones pesadas
