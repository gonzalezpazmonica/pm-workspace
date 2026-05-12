---
name: inbox-start
description: >
  Iniciar monitor de inbox en background. Revisa canales cada N minutos
  mientras la sesión de Claude Code esté abierta.
---

# Inbox Start

**Argumentos:** $ARGUMENTS

> Uso: `/inbox-start` o `/inbox-start --interval 2 --channels wa`

## Parámetros

- `--interval {minutos}` — Frecuencia de polling en minutos (defecto: 5)
- `--channels {wa|nctalk|all}` — Canales a monitorizar (defecto: todos activos)
- `--quiet` — No mostrar mensajes informativos (solo audios y acciones)
- `--stop` — Detener el monitor en background

## Contexto requerido

1. @docs/rules/domain/messaging-config.md — Config canales activos
2. `.opencode/skills/voice-inbox/SKILL.md` — Transcripción de audio

## Pasos de ejecución

### 1. Verificar canales
- Leer `messaging-config.md` → canales habilitados
- Verificar conexión de cada canal activo
- Si ningún canal activo → error con instrucciones de configuración

### 2. Lanzar proceso en background

Crear script de polling y ejecutar como tarea en background:

```bash
#!/bin/bash
# inbox-monitor.sh — se ejecuta como background task
INTERVAL=${1:-300}  # segundos (5 min por defecto)
INBOX_DIR="inbox"
mkdir -p "$INBOX_DIR/transcriptions"

while true; do
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Marcar que el monitor está activo
  echo "$TIMESTAMP" > "$INBOX_DIR/monitor-heartbeat.txt"

  # Invocar inbox-check internamente
  # (la lógica real la ejecuta Claude al leer los resultados)
  echo "CHECK_REQUESTED:$TIMESTAMP" >> "$INBOX_DIR/check-queue.txt"

  sleep $INTERVAL
done
```

El proceso se lanza con `&` y Claude registra el task ID.

### 3. Confirmar inicio

```
✅ Inbox monitor iniciado
Intervalo: cada 5 minutos
Canales: WhatsApp ✅, Nextcloud Talk ✅
Task ID: bg-inbox-7a3f
Detener: /inbox-start --stop

Próximo check: 11:05 (en 5 min)
```

### 4. Ciclo de monitorización

Cada N minutos, Claude recibe la señal del background task y ejecuta:
1. `/inbox-check` silencioso
2. Si hay mensajes nuevos → notificar al PM en la conversación
3. Si hay audios → transcribir y proponer acciones
4. Si no hay nada nuevo → silencio (no interrumpir)

### Modo `--stop`
- Localizar task en background por ID
- Detener el proceso
- Mostrar resumen de la sesión de monitorización:

```
⏹️ Inbox monitor detenido
Duración: 2h 15min | Checks realizados: 27
Mensajes procesados: 12 | Audios transcritos: 3
Comandos ejecutados: 2
```

## Ejemplos de uso

```bash
# Inicio estándar (5 min, todos los canales)
/inbox-start

# Polling cada 2 minutos, solo WhatsApp
/inbox-start --interval 2 --channels wa

# Sin mensajes informativos (solo alertas y audios)
/inbox-start --quiet

# Detener
/inbox-start --stop
```

## Flujo típico de una sesión

```
PM: /context-load                   ← carga contexto del proyecto
PM: /inbox-start                    ← activa monitor de mensajes
PM: /sprint-status --project x      ← trabaja normalmente

  ... 10 minutos después ...

→ 📩 Nuevo audio de Ana García (WhatsApp):
→   "¿Puedes generar el informe ejecutivo para la reunión de las 12?"
→   → /report-executive --project sala-reservas
→   → ¿Ejecutar? (s/n)

PM: s                               ← confirma
→ ✅ Informe generado: output/reports/20260227-executive-sala-reservas.md
→ ¿Enviar a Ana por WhatsApp? (s/n)

PM: s
→ ✅ Informe enviado a Ana García por WhatsApp
```

## Restricciones

- El monitor se detiene automáticamente al cerrar la sesión
- Solo un monitor activo a la vez (si ya hay uno corriendo, avisa)
- El intervalo mínimo es 1 minuto (evitar spam a las APIs)
- Requiere al menos un canal configurado y operativo
