# Eval 02 — Hallazgo de seguridad en código de carga de ficheros

## Contexto

El equipo ha implementado un endpoint de subida de ficheros en una API web.
El court-orchestrator debe detectar vulnerabilidades específicas de seguridad
y emitir un veredicto que priorice los hallazgos del juez de seguridad.

## Descripción del código a revisar

El fragmento implementa un controlador para subida de ficheros con estas características:
- Acepta cualquier tipo de fichero sin validar la extensión ni el tipo MIME
- Guarda el fichero usando el nombre original proporcionado por el cliente (sin sanitizar)
- Construye la ruta de destino concatenando directamente el nombre del fichero del cliente
- No tiene límite de tamaño de fichero
- No verifica si el fichero ya existe antes de sobrescribir
- Devuelve la ruta completa del servidor donde se guardó el fichero en la respuesta

## Tarea para el court-orchestrator

Ejecuta el Code Review Court enfocado en seguridad. El juez de seguridad debe
liderar el análisis. El tribunal debe:
- Identificar todas las vulnerabilidades presentes
- Asignar vectores de ataque a cada hallazgo (path traversal, unrestricted upload, etc.)
- Determinar el nivel de explotabilidad de cada vulnerabilidad
- Emitir veredicto REJECTED con lista de correcciones bloqueantes
- Proporcionar el patrón de corrección recomendado para cada hallazgo
