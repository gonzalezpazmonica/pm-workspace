# /marketplace-publish

Empaqueta, valida y publica una habilidad en el marketplace local. Crea un paquete estándar con SKILL.md, DOMAIN.md, referencias y metadata.json. Verifica estructura, límites de líneas, PII y compatibilidad de versiones antes de publicar.

## Parámetros

`$ARGUMENTS` = nombre-habilidad (sin espacios, kebab-case)

Ejemplo: `/marketplace-publish user-authentication`

## Razonamiento

Piensa paso a paso:
1. Verificar que la habilidad existe en `.claude/skills/{nombre}`
2. Validar estructura (SKILL.md 120 líneas máx, DOMAIN.md 40 líneas máx)
3. Validar metadata.json completo
4. Escanear PII en documentación
5. Verificar dependencias resolubles
6. Añadir a `data/marketplace/registry.json`

## Validaciones

- ✅ Estructura obligatoria: SKILL.md, DOMAIN.md, metadata.json
- ✅ Límites de líneas: SKILL.md ≤ 120, DOMAIN.md ≤ 40
- ✅ Metadata fields: name, version, author, category, tags, dependencies, compatibility
- ✅ Sin PII (emails, nombres reales, datos personales)
- ✅ Versioning semántico (X.Y.Z)
- ✅ Categoría válida: planning|development|testing|operations|reporting|compliance|communication

## Flujo de Ejecución

1. Cargar skill desde `.claude/skills/{nombre}`
2. Validar ficheros y líneas
3. Parsear metadata.json
4. Scanear PII en SKILL.md + DOMAIN.md
5. Verificar dependencias en registry.json existente
6. Generar entrada de registry
7. Actualizar `data/marketplace/registry.json`
8. Mostrar resumen publicación

## Salida

```
✅ Skill published: {nombre} v{version}
  Category: {category}
  Tags: {tags}
  Registry: data/marketplace/registry.json
```
