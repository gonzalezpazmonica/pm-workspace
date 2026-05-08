# sovereignty-auditor — Dominio

## Por que existe esta skill

La dependencia excesiva de un proveedor de IA crea riesgo estrategico: si el proveedor cambia precios, condiciones o desaparece, la organizacion pierde capacidad operativa. Esta skill diagnostica el nivel de lock-in, mide la portabilidad real de los datos y genera un plan de salida concreto. Implementa el principio foundacional #2 de Savia: independencia del proveedor.

## Conceptos de dominio

- **Sovereignty score**: puntuacion 0-100 ponderada de 5 dimensiones que mide cuanto control real tiene la organizacion sobre sus datos y procesos
- **Portabilidad de datos**: porcentaje de datos en formatos abiertos (md, csv, json) vs propietarios, con verificacion de SaviaHub y BacklogGit
- **Independencia LLM**: capacidad de operar sin el proveedor principal (emergency mode con Ollama, variedad de modelos, portabilidad de prompts)
- **Exit plan**: documento que inventaria datos, dependencias y estima esfuerzo de migracion con timeline realista

## Reglas de negocio que implementa

- Principio foundacional #2: independencia del proveedor (cognitive-sovereignty.md)
- Principio foundacional #1: soberania del dato (.md es la verdad)
- Principio foundacional #4: privacidad absoluta (datos nunca salen sin consentimiento)
- Regla de data-sovereignty: clasificacion local obligatoria antes de enviar datos a APIs cloud

## Relacion con otras skills

- **Upstream**: `governance-enterprise` (politicas de gobernanza alimentan la auditoria)
- **Upstream**: `personal-vault` y `savia-hub-sync` (portabilidad real de datos)
- **Downstream**: `emergency-mode` (recomendacion D2 activa el modo emergencia con LLM local)
- **Paralelo**: `regulatory-compliance` (compliance regulatorio complementa soberania cognitiva)

## Decisiones clave

- 5 dimensiones ponderadas (no un score binario): la soberania no es todo-o-nada, tiene gradientes
- El scan NUNCA envia datos a APIs externas: seria contradictorio auditar soberania enviando datos fuera
- Exit plan como documento, no como accion: el auditor informa, el humano ejecuta la migracion
- Recomendaciones ordenadas por quick-wins: maximizar impacto con minimo esfuerzo primero
