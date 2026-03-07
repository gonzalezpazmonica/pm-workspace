---
name: record-export
description: Export recorded session or data in multiple formats
---

---

# /record-export

Exporta una sesión grabada como informe markdown con formato legible para documentación, auditoría o capacitación.

## Parámetros

- `$ARGUMENTS`: ID de sesión a exportar (`session-YYYYMMDD-hash`)

## Comportamiento

- **Lectura**: Carga JSONL de la sesión
- **Procesamiento**: Transforma eventos en narrative markdown
- **Almacenamiento**: Guarda en `output/recordings/{session-id}-report.md`
- **Formato**: Documento estructurado con secciones, tablas y ejemplos

## Output

Informe markdown en:

```
📄 Informe generado: output/recordings/session-20260307-abc123-report.md
⏱️  Duración: 42 minutos
📊 Total eventos: 127
✅ Informe completo con timeline, decisiones y artefactos
```

Estructura del informe:
- Encabezado (ID sesión, duración, fecha)
- Timeline de acciones
- Archivos modificados
- Decisiones y notas
- Apéndice: comandos ejecutados

## Ejemplos

✅ Correcto:
```
PM: /record-export session-20260307-abc123
Savia: Informe guardado en output/recordings/session-20260307-abc123-report.md
```

❌ Incorrecto:
```
PM: /record-export session-inexistente
Savia: ❌ Sesión no encontrada
```
