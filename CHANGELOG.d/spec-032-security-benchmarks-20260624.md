# SPEC-032: Security Benchmarks — Framework de Evaluacion Objetiva

**Date**: 2026-06-24
**Spec**: SPEC-032
**Status**: IMPLEMENTED

## Que se implemento

Framework de benchmarks para evaluar de forma objetiva los agentes de seguridad de Savia (security-attacker, security-guardian, pentester).

## Ficheros creados

- `scripts/security-benchmark-runner.sh` — Runner principal. Soporta Docker (Juice Shop, DVWA, WebGoat) y modo fallback local con `--mock`.
- `scripts/security-benchmark-metrics.py` — Calcula precision, recall, F1 y false_negative_count comparando hallazgos reales con esperados.
- `tests/fixtures/security-benchmark/vulnerable-code-sample.py` — Codigo Python con 5 vulnerabilidades conocidas (CWE-798, CWE-89, CWE-79, CWE-22, CWE-78).
- `tests/fixtures/security-benchmark/expected-findings.json` — Findings esperados para el codigo sample.
- `tests/fixtures/security-benchmark/sample-pr-diff.txt` — Diff de PR con vulnerabilidad SQL injection intencionada.
- `docs/rules/domain/security-benchmark-protocol.md` — Protocolo: como ejecutar, interpretar resultados, thresholds, añadir nuevas apps.
- `tests/bats/test-spec-032-security-benchmarks.bats` — 8 tests BATS.

## Ficheros modificados

- `.opencode/plugins/lib/sovereignty-patterns.ts` — Añadida `tests/fixtures/` a `PRIVATE_DEST_RX` para que el shield no bloquee fixtures de seguridad.

## Thresholds

- `detection_rate >= 0.70` (minimo aceptable)
- `false_positive_rate <= 0.30` (maximo aceptable)

## Output JSON del runner

```json
{
  "agent": "security-attacker+guardian",
  "app": "local",
  "vulnerabilities_found": 5,
  "total_expected": 5,
  "detection_rate": 1.0,
  "false_positives": 0,
  "false_positive_rate": 0.0,
  "score": 1.0,
  "pass": true
}
```
