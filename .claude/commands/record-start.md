# /record-start

Inicia la grabación de la sesión actual. Todos los comandos, modificaciones de archivos y decisiones de agentes se registran en un archivo JSONL para auditoría y documentación posterior.

## Comportamiento

- **Sesión nueva**: Genera un ID de sesión único (`session-{timestamp}-{hash}`)
- **Grabación**: Crea fichero en `data/recordings/{session-id}.jsonl`
- **Eventos**: Cada acción registra tipo, timestamp, actor, contenido
- **Confirmación**: Muestra ID de sesión y ruta de almacenamiento

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /record-start — Grabación iniciada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎬 Sesión: session-20260307-abc123
📁 Archivo: data/recordings/session-20260307-abc123.jsonl
⏱️  Hora inicio: 2026-03-07T10:30:15Z

💡 Parar grabación: /record-stop
💾 Reproducir: /record-replay session-20260307-abc123
📊 Exportar: /record-export session-20260307-abc123
```

## Ejemplos

✅ Correcto:
```
PM: /record-start
Savia: Sesión iniciada. ID: session-20260307-xyz789
```

❌ Incorrecto:
```
PM: /record-start
Savia: [nada sucede, sin confirmación visual]
```
