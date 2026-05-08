# Regla: Resumen por pantalla tras generar fichero de datos

> **REGLA OPERATIVA** — Aplica cuando el usuario solicita datos y Savia genera un fichero como resultado (informes, listados, exports, queries persistidas).

## Principio

Generar un fichero NO sustituye la respuesta en pantalla. El usuario pidio **datos**, no un puntero a un fichero. El fichero es persistencia; la pantalla es respuesta.

## Cuando aplica

- Tras escribir cualquier fichero en `output/` que contenga datos pedidos por el usuario.
- Listados (PBIs, tasks, work items, miembros del equipo, sprints, incidencias).
- Reports (weekly, executive, time-tracking, cost).
- Exports (CSV, JSON, MD generados a partir de queries).
- Resultados de auditorias, scans, analisis.

## Cuando NO aplica

- Ficheros de configuracion o de codigo (no son "datos solicitados").
- Logs internos (audit logs, run logs).
- Ficheros que el usuario explicitamente pide generar sin verlos (ej. "guardalo y ya").

## Politica adaptativa por tamano

| Filas/items en el fichero | Salida en pantalla |
|---|---|
| < 30 | **Tabla completa** + agregados (estado, asignado, totales) |
| 30 - 150 | **Agregados completos** + **top 10-20 filas mas relevantes** + path al fichero |
| > 150 | **Agregados completos** + **muestra de 5-10 filas representativas** + path al fichero + nota explicita "ver fichero para listado completo" |

"Mas relevantes" = priorizar por: estado critico (blocked, new sin asignar), riesgo (sin SP, sin asignado), recencia (mas recientes primero) o el criterio que pidio el usuario.

## Estructura recomendada de la respuesta

```
1. Frase de cabecera con totales (1 linea)
2. Tabla / muestra segun tamano
3. Agregados (estado, asignado, etc.)
4. Anomalias o riesgos detectados (sin asignar, bloqueados, etc.)
5. Path al fichero generado
6. Pregunta de siguiente paso (opcional)
```

## Antipatron a evitar

```
"Generado: output/foo.md (12.9 KB, 139 lineas)."
[fin de respuesta]
```

Esto fuerza al usuario a pedir el contenido en un segundo turno. Es friccion innecesaria y rompe el flujo.

## Excepciones explicitas del usuario

Si el usuario dice "solo guarda" / "no lo muestres" / "dame solo el path", se respeta sin volcar contenido. La regla establece el default, no es absoluta.

## Origen

Leccion 2026-05-06: tras generar un informe en `output/` el agente solo mostro metadata del fichero; el usuario tuvo que pedir el contenido en un segundo turno.
