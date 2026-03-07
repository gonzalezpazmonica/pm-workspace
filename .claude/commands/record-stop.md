# /record-stop

Detiene la grabación de sesión actual y muestra un resumen de lo registrado.

## Comportamiento

- **Finalización**: Cierra el archivo JSONL de grabación
- **Resumen**: Calcula y muestra estadísticas
- **Limpieza**: Marca la sesión como completada

## Output

Resumen con:
- Duración total de la sesión
- Cantidad de eventos registrados (desglosado por tipo)
- Número de archivos modificados
- Ruta de almacenamiento del fichero JSONL

## Ejemplo

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /record-stop — Grabación completada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Resumen:
  Duración: 42 minutos
  Eventos: 127 total
    · Comandos: 18
    · Modificaciones: 45
    · Decisiones: 12
    · Notas: 52
  Archivos modificados: 8
📁 Grabación: data/recordings/session-20260307-abc123.jsonl

💾 Reproducir: /record-replay session-20260307-abc123
📋 Exportar: /record-export session-20260307-abc123
```
