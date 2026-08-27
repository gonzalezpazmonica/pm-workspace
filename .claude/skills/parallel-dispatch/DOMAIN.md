---
context_tier: L2
---

# DOMAIN: Despacho paralelo (admission-handle)

## Por qué existe esta skill

Patrón RLM de Prime Agent (SE-347): lanzar subagentes con un handle de admisión
inmediato y recoger resultados después, sin bloquear el turno del padre.

## Conceptos de dominio

- **Admission-handle**: el launch devuelve el id al instante; el trabajo corre
  en background en disco propio.
- **Jobs**: registro JSON por tarea (`~/.savia/dispatch/<id>.job.json`) con
  estado running/done/failed, exit code y output.
- **collect**: agrega stdout de jobs completados; `--fail-fast` marca error si
  alguno falló.

## Límites

- No sustituye a dag-scheduling cuando hay dependencias entre tareas.
- Los jobs en background no tienen supervisión humana en tiempo real → aplica
  autonomous-safety (PR Draft, revisión humana).

## Confidencialidad

- Resultados en `~/.savia/dispatch` (disco propio, CRIT-001). Nunca en el repo.
