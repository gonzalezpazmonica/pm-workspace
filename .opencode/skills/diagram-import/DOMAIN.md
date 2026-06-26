# Diagram Import — Dominio

## Por que existe esta skill

Los diagramas de arquitectura contienen informacion valiosa sobre componentes y
relaciones que puede traducirse en Features y PBIs. Esta skill importa diagramas,
valida reglas de negocio y genera work items en Azure DevOps con trazabilidad completa.

## Conceptos de dominio

- **Modelo normalizado**: representacion JSON de entidades y relaciones extraidas de cualquier formato de diagrama
- **Reconocimiento de shapes**: mapeo visual (rectangulo=servicio, cilindro=DB, hexagono=cola) a tipos de entidad
- **Validacion de reglas de negocio**: verificacion de que cada entidad tiene informacion suficiente antes de crear PBIs
- **Descomposicion Feature/PBI**: agrupacion de entidades en Features y generacion de PBIs con estimacion

## Reglas de negocio que implementa

- Diagram Config (diagram-config.md): tabla de informacion requerida por tipo de entidad
- PBI Decomposition: generacion de tasks con estimacion segun politica-estimacion.md
- Autonomous Safety (autonomous-safety.md): confirmacion humana obligatoria antes de crear work items

## Relacion con otras skills

- **Upstream**: diagram-generation (produce los diagramas que esta skill importa)
- **Downstream**: pbi-decomposition (descompone los PBIs generados en tasks tecnicas)
- **Paralelo**: backlog-capture (tambien crea PBIs pero desde input desestructurado, no diagramas)

## Decisiones clave

- No crear PBIs sin reglas de negocio: evitar work items vacios que generan retrabajo
- Soporte multi-formato (Draw.io XML, Miro JSON, Mermaid): flexibilidad sin forzar herramienta
- Propuesta completa al PM antes de crear: nunca escribir en Azure DevOps sin confirmacion explicita
