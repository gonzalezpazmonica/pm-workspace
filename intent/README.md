# intent/ — re-entrada al pipeline (SE-357)

> Home de los `intent.md` que re-entran al pipeline SDD cuando un control band
> se rompe (3σ) o un hallazgo autónomo supera el tamaño de un PR.
> Formato Stage 1 (Anthropic playbook): problema, evidencia, outcome propuesto,
> sistemas afectados, preguntas abiertas.

## Uso

1. Un agente autónomo (SE-357) detecta un breach 3σ y escribe aquí un `intent.md`.
2. La operadora hace triage: **fix | schedule | dismiss**.
3. Un intent aceptado inicia el pipeline SDD (spec → plan → build → review).

## Gobernanza

- Triage humano siempre (la IA propone, el humano dispone).
- `dismiss` tunca los bands de la métrica (reduce ruido).
- Los intents aceptados se referencian desde el PR que los implementa.
