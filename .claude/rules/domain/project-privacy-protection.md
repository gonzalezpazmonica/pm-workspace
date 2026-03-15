---
globs: ["projects/**", ".gitignore"]
---
# Regla: Protección de Privacidad de Proyectos

## Contexto

El directorio `projects/` contiene proyectos que pueden ser privados (clientes,
datos sensibles, propiedad intelectual). El `.gitignore` del workspace aplica
una política deny-by-default: todos los proyectos nuevos quedan excluidos del
repositorio git automáticamente. Solo los proyectos explícitamente whitelisteados
con `!projects/nombre/` se publican.

## Regla OBLIGATORIA

**NUNCA modificar `.gitignore` para añadir un whitelist de proyecto (`!projects/...`)
sin confirmación explícita de la persona humana en la conversación.**

Esto incluye:

- Añadir líneas `!projects/nuevo-proyecto/` al .gitignore
- Usar `git add -f` para forzar el tracking de un proyecto ignorado
- Mover contenido de un proyecto a una ruta no ignorada para evadir la protección
- Cualquier otro mecanismo que resulte en publicar un proyecto no autorizado

## Procedimiento obligatorio

1. **Informar al humano** del estado actual: el proyecto está ignorado por defecto
2. **Preguntar explícitamente**: "¿Este proyecto debe ser público en el repo? Modificar
   .gitignore para incluirlo requiere tu confirmación."
3. **Esperar respuesta afirmativa** en la conversación antes de proceder
4. **Si hay duda**, NO incluir. Es preferible un paso extra que una filtración.

## Justificación

Un error en este punto puede causar:
- Filtración de datos de clientes (violación RGPD/LOPD)
- Exposición de propiedad intelectual
- Ruptura de acuerdos de confidencialidad (NDA)
- Responsabilidad legal directa

## Mecanismo de defensa adicional

Además de esta regla, existe un hook de git pre-commit (`scripts/protect-project-privacy.sh`)
que actúa como barrera independiente. Aunque Savia ignore esta regla por error de contexto,
el hook bloqueará el commit y pedirá confirmación interactiva.
