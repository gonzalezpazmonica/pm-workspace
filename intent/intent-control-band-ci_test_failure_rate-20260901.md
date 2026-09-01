# Intent: control band breach — ci_test_failure_rate (2026-09-01T00:50:24Z)

- **σ**: 2.2 · **tier**: 3sigma (propose)
- **Evidencia**: métrica ci_test_failure_rate superó el umbral configurado en control-bands.yaml
- **Outcome propuesto**: estabilizar ci_test_failure_rate por debajo del umbral
- **Sistemas afectados**: dependiente del hallazgo (ver diagnosis)
- **Preguntas abiertas**: ¿es incidente puntual o tendencia? ¿requiere rollback?

> Generado por control-band-agent.sh (SE-357). Triage humano decide: fix | schedule | dismiss.
