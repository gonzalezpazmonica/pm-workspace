---
context_tier: L2
token_budget: 586
---

# Radical Honesty — Enforcement (SPEC-192)

> Anexo bajo demanda de `radical-honesty.md` (SPEC-181). La regla y sus
> prohibiciones viven en el núcleo eager; aquí, cómo se hacen cumplir.

Esta regla tiene tres mecanismos complementarios, no una intercepción completa
de cada respuesta final:

**Layer 1 (deterministic, sin LLM):** hook `.opencode/hooks/sycophancy-strip.sh`
ejecuta regex contra outputs de herramientas o subagentes observables por los
hooks. Bloquea (en mode=block) frases
explicitas como "Buena pregunta", "Tienes razon", "Absolutamente" cuando
aparecen al inicio del draft. Vease `scripts/anti-adulation/regex-patterns.json`
para la lista completa.

**Layer 2 (LLM judges):** Recommendation Tribunal (SPEC-125) extendido con tres
jueces nuevos que evaluan adulacion semantica sutil:

- `sycophancy-judge` (mode warn por defecto): detecta validacion social vacia
  que no aporta contenido informativo.
- `concession-judge` (mode shadow): detecta cambios de postura del asistente
  sin nueva evidencia introducida por el usuario.
- `repetition-truth-judge` (mode shadow): evalua claims materiales desde la
  primera mencion y detecta los citados como hecho sin verificacion.

**Layer 3 (skill activa):** `.opencode/skills/epistemic-humility/SKILL.md`
proporciona protocolo de reemplazos concretos cuando el modelo se autodetecta
en uno de los tres patrones. Carga automatica via tribunal trigger o keyword.

Telemetria de los tres patrones se registra en
`output/anti-adulation-telemetry.jsonl`. Datos recopilados por 30 dias antes
de promover los modos shadow a warn.

SE-309 añade evaluación contrafactual reproducible para feedback bias, answer
switching, belief conformity y false-premise mimicry. Ejecución local:
`python scripts/anti-adulation/evaluate_sycophancy.py --corpus tests/evals/anti-sycophancy-corpus.json --results tests/evals/anti-sycophancy-results-clean.jsonl --thresholds`.
Claude Code y OpenCode no exponen actualmente un evento pre-entrega fiable; por
tanto estos mecanismos no garantizan filtrar toda respuesta final nativa.

Bypass de emergencia: `SAVIA_ANTIADULATION=off` desactiva los componentes que
respetan ese switch; no sustituye la limitacion de cobertura anterior.
Solo justificable para tests; no para uso normal.
