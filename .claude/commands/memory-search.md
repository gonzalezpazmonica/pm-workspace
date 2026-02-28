---
name: memory-search
description: >
  Busca en la memoria persistente. Útil para recordar decisiones, bugs y patrones de sesiones anteriores.
---

# ⚡ Buscar en Memoria

Busca observaciones guardadas en la memoria persistente del proyecto.

## Uso

```
/memory-search {query}
```

### Parámetros

- **query**: Término de búsqueda (palabra clave, decisión, bug, patrón, etc.)

## Proceso

**1. Inicio**
```
═══════════════════════════════════════════════════════════
🔍 BUSCAR EN MEMORIA PERSISTENTE
═══════════════════════════════════════════════════════════
```

**2. Búsqueda**
```bash
bash scripts/memory-store.sh search "{query}"
```

**3. Formato de resultados**
Muestro hasta 10 resultados agrupados por:
- **Tipo**: decision, bug, pattern, convention, discovery
- **Timestamp**: Cuándo se guardó
- **Contenido**: Resumen de la observación
- **Archivos**: Referencias de archivos afectados

**4. Sin resultados**
Si no hay coincidencias, sugiero:
- Términos más amplios
- Variaciones de palabras clave
- Browsear todo con `/memory-context`

**5. Fin**
```
═══════════════════════════════════════════════════════════
✅ Búsqueda completada
⚡ Tip: usa /memory-context para ver contexto del proyecto
═══════════════════════════════════════════════════════════
```

## Ejemplos

```
/memory-search autenticación

/memory-search bug performance

/memory-search JWT

/memory-search "error handling"

/memory-search patrón
```

## Restricciones

- ✓ Solo lectura
- ✗ No modifica memoria
- ✗ No ejecuta comandos
