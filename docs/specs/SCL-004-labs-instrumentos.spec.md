# SCL-004 — Labs L1: divergencia grafo-modelo como instrumento del bucle

**Status:** APPROVED → IMPLEMENTED (2026-08-17)
**Fecha:** 2026-08-17
**Area:** Memoria / Epistemología / Savia Labs (L1)
**Branch:** agent/scl-001-aprendizaje-continuo
**Estimación:** ~4h

---

## Origen

SCL-001 S3 define la métrica `L` con componente `divergencia` (Labs L1): la
distancia entre lo que el grafo de SaviaVaults afirma y lo que el modelo
declaró. Hasta ahora ese componente no tenía instrumento real. Esta spec lo
implementa: `learning-divergence.sh` mide la divergencia grafo-modelo y, si
supera umbral, dispara una propuesta de revisión (trigger `divergence`) — el
"el modelo ignora/contradice el conocimiento persistido" detectado y convertido
en propuesta de corrección.

## Diseño

```
claim del modelo (texto) ─┐
                          ├→ divergencia = 1 − (términos claim ∩ términos grafo) / |términos grafo|
grafo (snippet de cúpula) ─┘
divergencia > umbral → learning-proposal.sh --trigger divergence (revisión)
```

Determinista: extrae términos significativos (>=4 chars, sin stopwords) de ambos
lados. 0 = modelo alineado con el grafo; 1 = modelo ignora el grafo.

## Acceptance criteria

- AC-1. Claim alineado con el grafo → divergencia ≤ umbral, exit 0 (test).
- AC-2. Claim divergente → divergencia > umbral, exit 1 (test).
- AC-3. Determinismo: misma entrada → mismo valor de divergencia (test).
- AC-4. `--propose` + divergencia → genera propuesta con `trigger: divergence`
  (test).
- AC-5. Claim alineado + `--propose` → NO genera propuesta (test).
- AC-6. Grafo vacío → divergencia máxima (exit 1) (test).
- AC-7. `--json` emite JSON válido (test).

## Verification method

1. Suite BATS `tests/test-scl-004-divergencia.bats` (7 tests).
2. E2E: claim divergente con `--propose` genera propuesta con trigger
   `divergence`; la propuesta entra al ciclo de SCL-001 (shadow).

## Out of scope

- Ejecución de Labs L2-L6: SCL-004 solo instrumenta L1 (divergencia). El resto
  de Labs queda para SCL-004 futura / SE-291 S2-S8.
- Embeddings híbridos para la divergencia: SCL-005 (bloqueado por infra).

## Referencias

- SCL-001 S3: métrica `L` (componente divergencia)
- Savia Labs L1: divergencia grafo-modelo (SE-291)
- Script: `scripts/learning-divergence.sh`
