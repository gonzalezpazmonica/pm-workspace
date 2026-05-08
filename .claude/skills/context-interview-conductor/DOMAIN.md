# Context Interview Conductor — Dominio

## Por que existe esta skill

Los proyectos nuevos arrancan con informacion fragmentada e incompleta. Esta skill
conduce una entrevista estructurada de 8 fases que captura dominio, stakeholders,
stack, restricciones, reglas de negocio, compliance, timeline y validacion final.

## Conceptos de dominio

- **Entrevista de 8 fases**: secuencia estructurada desde dominio hasta validacion final del contexto
- **Gap**: campo esperado en el esquema minimo de una fase que no tiene respuesta
- **Preguntas adaptativas**: variantes de fase 6 (compliance) segun sector del cliente (fintech, healthcare, general)
- **Persistencia inmediata**: cada respuesta se guarda en disco al instante, sin esperar al final
- **Sesion**: fichero markdown con frontmatter YAML que registra estado, fase actual y respuestas

## Reglas de negocio que implementa

- Context Interview Config (context-interview-config.md): esquema de 8 fases y campos minimos
- Digest Traceability (digest-traceability.md): cada sesion se registra como fuente procesada
- Context Placement (context-placement-confirmation.md): datos de cliente van a N4 (SaviaHub)

## Relacion con otras skills

- **Upstream**: client-profile-manager (crea el cliente en SaviaHub antes de la entrevista)
- **Downstream**: savia-hub-sync (persiste los resultados en el repo compartido)
- **Paralelo**: product-discovery (captura similar pero enfocada en JTBD, no en contexto completo)

## Decisiones clave

- Una pregunta a la vez: evita sobrecarga cognitiva del PM, mejora calidad de respuestas
- Gaps no bloquean avance: marcar y seguir es mejor que forzar respuestas inventadas
- Sector detectado desde profile.md: si no existe, se pregunta en fase 1 para adaptar compliance
