# /marketplace-search

Busca habilidades en el marketplace local por palabra clave, categoría o tags. Devuelve lista de skills que coinciden con filtros.

## Parámetros

`$ARGUMENTS` = palabra-clave | category:{nombre} | tag:{nombre}

Ejemplos:
- `/marketplace-search planning`
- `/marketplace-search category:development`
- `/marketplace-search tag:database`

## Búsqueda

Coincide contra:
- Nombre de la habilidad
- Descripción en metadata.json
- Categoría
- Tags

## Razonamiento

1. Parsear `$ARGUMENTS` para tipo (palabra clave, categoría, tag)
2. Cargar `data/marketplace/registry.json`
3. Filtrar skills por criterio
4. Enriquecer con metadata (author, version, tags)
5. Ordenar por relevancia

## Salida

```
📦 Marketplace Search — {query}
{count} skills encontradas:

| Nombre | Versión | Categoría | Tags | Autor |
|--------|---------|-----------|------|-------|
```

Mostrar también: descripción breve, dependencias, si está instalada.
