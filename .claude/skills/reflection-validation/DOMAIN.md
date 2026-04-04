# Reflection Validation -- Dominio

## Por que existe esta skill

Los LLMs operan por defecto en System 1 (rapido, heuristico), produciendo respuestas plausibles pero potencialmente incorrectas. Esta skill fuerza System 2 (deliberado, critico) mediante un protocolo de 5 pasos que detecta optimizacion proxy, supuestos no declarados y cadenas causales rotas.

## Conceptos de dominio

- **System 1 vs System 2**: dual-process theory de Kahneman; System 1 genera la respuesta, System 2 la verifica.
- **Proxy optimization**: responder al objetivo literal en vez del real (ej: optimizar desplazamiento cuando el objetivo es lavar el coche).
- **Assumption audit**: lista explicita de todo lo que se dio por supuesto; minimo 3 supuestos por respuesta.
- **Mental simulation**: recorrer la recomendacion paso a paso hasta verificar que alcanza el objetivo real.
- **Gap types**: prerequisito faltante, variable incorrecta, constraint ignorada, anchoring, satisficing, narrow framing.

## Reglas de negocio que implementa

- consensus-protocol.md: reflection-validator es juez con peso 0.4 en el panel de 3 jueces.
- Verdicts: VALIDATED (sin gaps), CORRECTED (gap detectado y corregido), REQUIRES_RETHINKING (gap fundamental).
- Embeddable Pattern: agentes pueden incluir el bloque de auto-reflexion sin invocar al agente externo.
- adaptive-output.md: Step 1 del protocolo se aplica tambien a respuestas fuera de scope (real objective check).

## Relacion con otras skills

- **Upstream**: cualquier skill o agente que genere output evaluable.
- **Downstream**: consensus-validation (reflection-validator como juez), spec-driven-development (validacion de specs).
- **Paralelo**: coherence-check (coherencia output-objetivo vs esta skill que verifica razonamiento profundo).

## Decisiones clave

- 5 pasos sobre checklist generico: cada paso ataca un tipo de fallo cognitivo especifico.
- Embeddable pattern sobre invocacion obligatoria: permite auto-reflexion sin coste de subagente.
- System 2 explicito sobre "piensa mas": la estructura guiada produce resultados mas consistentes.
