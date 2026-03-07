# Regla: CHANGELOG.md — Integridad y Buenas Prácticas

## Problema

El CHANGELOG.md es un punto caliente de conflictos de merge. Cuando múltiples
ramas lo modifican simultáneamente, la resolución de conflictos puede:

1. **Truncar entradas** — eliminar versiones existentes al quedarse con una rama
2. **Desordenar versiones** — dejar una versión mayor después de una menor
3. **Dejar marcadores de conflicto** — `<<<<<<<`, `=======`, `>>>>>>>` residuales
4. **Duplicar entradas** — la misma versión aparece dos veces
5. **Perder la cabecera** — sobreescribir la cabecera estándar con la de una rama

## Reglas obligatorias al modificar CHANGELOG.md

1. **Solo añadir AL INICIO** — nueva entrada siempre después de la cabecera
2. **Versión descendente estricta** — cada `## [x.y.z]` debe ser menor que la anterior
3. **Sin gaps mayores a 2 minor** — si faltan versiones, buscar si se perdieron
4. **Formato obligatorio** — `## [x.y.z] — YYYY-MM-DD`
5. **Links comparativos** — `[x.y.z]: https://github.com/.../compare/vA...vB` al final
6. **Tras resolver conflictos** — verificar SIEMPRE con:
   ```bash
   grep -c '^## \[' CHANGELOG.md  # contar entradas (debe coincidir con pre-merge)
   grep -E '^(<<<<|====|>>>>)' CHANGELOG.md  # cero resultados
   ```
7. **Pre-push** — `bash scripts/validate-ci-local.sh --quick` incluye check de integridad

## Para agentes

Cuando un agente modifica CHANGELOG.md, DEBE:

- Leer la versión más alta actual ANTES de escribir
- Usar versión = más_alta + 0.1.0 (o +1.0.0 si major change)
- Verificar tras escribir que `grep '^## \[' CHANGELOG.md` muestra orden descendente
- NUNCA reemplazar el contenido completo del archivo — solo insertar la nueva entrada
- Si hay conflicto de merge, preservar TODAS las entradas de ambas ramas
