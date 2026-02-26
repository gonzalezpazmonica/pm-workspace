# Regla: Límite de 150 líneas por fichero

> Aplicable a TODO fichero creado o modificado dentro de pm-workspace.

---

## Límite

Ningún fichero debe superar **150 líneas** de contenido.
Esto aplica a código fuente, reglas, convenciones, documentación, agentes, skills, scripts, tests y cualquier otro tipo de fichero.

## Qué hacer cuando un fichero supera el límite

1. **Código fuente** → Extraer clases/funciones a ficheros separados siguiendo SRP (Single Responsibility Principle).
2. **Documentación (.md)** → Dividir en secciones enlazadas (como `docs/readme/`).
3. **Reglas y convenciones** → Separar en ficheros temáticos dentro de `.claude/rules/`.
4. **Tests** → Un fichero por clase/módulo bajo prueba; compartir fixtures en helpers.
5. **Agentes** → Si el prompt crece, externalizar tablas de referencia a ficheros auxiliares.

## Excepción: Software legacy heredado

Los ficheros de **código legacy externo** que no hayan sido creados dentro de pm-workspace y nos lleguen heredados **no se refactorizan** para cumplir este límite.

Solo se refactorizará legacy si el PM lo solicita expresamente mediante una tarea en el backlog.

> **Criterio de legacy**: fichero que existía antes de incorporar el proyecto a pm-workspace y no fue generado por ningún agente ni desarrollador del equipo actual.

## Verificación

- `commit-guardian` debe comprobar que ningún fichero nuevo o modificado en el commit exceda 150 líneas (excluir legacy).
- Si un fichero existente propio ya supera el límite al modificarlo, refactorizarlo como parte del cambio.
