---
tier: core
description: "Busca comandos en catálogo extendido por keyword o área"
---
Lista comandos en el catálogo extendido (tier: extended) que coinciden con $ARGUMENTS.
Busca en nombre y description. Si se invoca sin argumento, lista todos los extended.
Para cada resultado muestra: nombre, description, última modificación.
Los comandos listados quedan disponibles para invocar en esta sesión.

## Implementación

1. Lee todos los `.md` en `.claude/commands/`
2. Filtra los que tengan `tier: extended` en el frontmatter
3. Si $ARGUMENTS no está vacío, filtra además por coincidencia de $ARGUMENTS en nombre o campo `description:` del frontmatter
4. Para cada resultado extrae y muestra:
   - **Nombre**: nombre del fichero sin `.md`
   - **Description**: valor del campo `description:` del frontmatter
   - **Última modificación**: `git log --format="%ad" --date=format:"%Y-%m-%d" -1 -- <file>`
5. Ordena por nombre
6. Al final muestra el total de coincidencias
7. Informa al usuario que los comandos listados están disponibles en la sesión actual

## Ejemplo de salida

Comandos extended que coinciden con "arch":
  arch-compare     - Comparación de arquitecturas alternativas   (2026-03-01)
  arch-fitness     - Fitness functions de arquitectura            (2026-03-01)
  arch-suggest     - Sugerencias de mejora arquitectónica        (2026-03-01)

Total: 3 comandos. Disponibles en esta sesión.
