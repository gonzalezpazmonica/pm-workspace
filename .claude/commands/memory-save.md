---
name: memory-save
description: >
  Guarda una observación en la memoria persistente. Tipos: decision, bug, pattern, convention, discovery.
  Soporta topic_key para evolucionar decisiones sin duplicar.
---

# ⚡ Guardar en Memoria Persistente

Guarda observaciones clave en la memoria persistente del proyecto para reutilizar en futuras sesiones.

## Uso

```
/memory-save {tipo} {título}
/memory-save --topic {key} {tipo} {título}
```

### Parámetros

- **tipo**: `decision`, `bug`, `pattern`, `convention` o `discovery`
- **título**: Breve descripción del item
- **--topic {key}** (opcional): Clave para agrupar evoluciones sin duplicar

## Proceso

**1. Inicio**
```
═══════════════════════════════════════════════════════════
⚙️ GUARDAR EN MEMORIA PERSISTENTE
═══════════════════════════════════════════════════════════
```

**2. Parse de argumentos**
Extraigo `tipo`, `título` y `--topic` (si existe) de tu entrada.

**3. Solicito contenido**
Te pido que completes:
- Qué recordar (descripción detallada)
- Por qué es importante
- Archivos afectados (si aplica)

**4. Limpieza**
Elimino tags `<private>` del contenido.

**5. Ejecución**
```bash
bash scripts/memory-store.sh save \
  --type {tipo} \
  --title "{título}" \
  --content "{content}" \
  [--topic {key}] \
  [--project {proyecto_activo}]
```

**6. Confirmación**
Muestro resumen del entry guardado con timestamp y ID.

**7. Fin**
```
═══════════════════════════════════════════════════════════
✅ Entrada guardada exitosamente
⚡ Tip: usa /memory-search para recuperar información
═══════════════════════════════════════════════════════════
```

## Ejemplos

```
/memory-save decision "Migrar autenticación a JWT"

/memory-save --topic "auth_strategy" decision "JWT en lugar de sessions"

/memory-save bug "Query N+1 en listado de usuarios"

/memory-save pattern "Error handling con try-catch async"

/memory-save convention "Nombrar funciones auxiliares con prefijo _"

/memory-save discovery "Redis mejora performance 40% en caché"
```

## Restricciones

- ✓ Solo escribe en memoria persistente
- ✗ No modifica otros archivos
- ✗ No ejecuta comandos del proyecto
