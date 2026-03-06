---
name: skill-auto-activation
description: Regla para activación inteligente de skills basada en contexto
---

# Skill Auto-Activation Protocol

## Cuándo se aplica

Cada vez que el usuario inicia una interacción que podría beneficiarse de un skill especializado.

## Protocolo

1. **Detección**: Al recibir un prompt, evaluar si algún skill disponible tiene relevancia >70%
2. **Sugerencia**: Si se detecta match, informar al usuario: "Skill `{nombre}` podría ayudar aquí. ¿Lo activo?"
3. **Confirmación**: NUNCA activar sin confirmación explícita del usuario
4. **Registro**: Registrar cada activación y su resultado en `.claude/skills/eval-registry.json`
5. **Aprendizaje**: Si el usuario rechaza la sugerencia 3 veces consecutivas para el mismo skill+contexto, dejar de sugerir

## Scoring

- keyword_match: 40% del score
- project_context: 30% del score (basado en tipo de proyecto y ficheros)
- history_boost: 30% del score (basado en activaciones previas exitosas)
- Threshold mínimo para sugerir: 70%

## Restricciones

- No sugerir más de 2 skills por interacción
- No sugerir skills durante `/focus-mode` activo
- Respetar feedback negativo del usuario (tune -)
- Los skills de seguridad (security-guardian, pii-gate) siempre tienen prioridad
