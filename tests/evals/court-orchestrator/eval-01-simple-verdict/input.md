# Eval 01 — Veredicto simple de revisión de código

## Contexto

El equipo ha subido un PR con una implementación de repositorio en C#.
El court-orchestrator debe revisar el código, convocar los jueces y emitir
un veredicto final con hallazgos clasificados por severidad.

## Fragmento de código a revisar

El fragmento muestra una clase TaskRepository con cuatro métodos. El método
GetByIdAsync construye una consulta de base de datos concatenando directamente
el parámetro `id` en el texto de la consulta (interpolación de string sin
parametrización). El método GetAllAsync carga todos los registros sin límite.
El método CreateAsync usa DateTime.Now (local) en lugar de DateTime.UtcNow.

Detalles del fragmento (para el juez de seguridad):
- Línea con vulnerabilidad: construcción de query con interpolación directa de parámetro externo
- Método GetAllAsync: sin paginación ni límite, potencialmente carga toda la tabla
- Uso de DateTime.Now: zona horaria local en lugar de UTC

## Tarea para el court-orchestrator

Convoca el tribunal completo (jueces de seguridad, correctitud, arquitectura,
cognitivo y spec-compliance), ejecuta el Code Review Court sobre este fragmento,
y produce el fichero de revisión con:
- Score global (0-100)
- Hallazgos por juez con severidad (CRITICAL / HIGH / MEDIUM / LOW)
- Veredicto: APPROVED / APPROVED_WITH_CHANGES / CHANGES_REQUIRED / REJECTED
- Ciclos de corrección necesarios antes de merge
