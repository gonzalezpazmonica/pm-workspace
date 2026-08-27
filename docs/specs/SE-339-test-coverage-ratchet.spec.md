# SE-339 — Ratchet de test-coverage para hooks críticos (cierra SE-046)

**Status:** IMPLEMENTED (2026-08-27, PR Batch 1 L14 — ratchet + allowlist + doc TS tests)
**Fecha:** 2026-08-23
**Area:** Calidad / Tests / Integridad
**Origen:** SaviaLabs L14 · deuda técnica 2.1 (coverage 23%)
**Developer Type:** agent-single
**Context risk:** low
**Estimación:** agente ~4-6h / revisión humana 20min

---

## 1. Problema y objetivo

La cobertura de tests de hooks es **23%** (113 hooks totales, ~26 con BATS).
Los hooks de seguridad (PII, commits, branch, fuerza, credenciales) son los más
críticos y no todos tienen test. Además, los tests TS de los plugins OpenCode
usán `bun:test` (runtime del frontend) y no corren desde CLI con `node --test`
(MODULE_NOT_FOUND), así que quedan fuera de la verificación local.

El objetivo: un **ratchet mínimo no decreciente** de cobertura sobre los hooks
críticos, y documentación canónica de cómo correr los tests TS.

## 2. Contratos

### 2.1 Categorización de hooks críticos

`tests/hooks/critical-hooks.txt` — allowlist de hooks que deben tener BATS:
block-credential-leak, block-force-push, block-branch-switch-dirty,
block-commit-to-main, block-infra-destructive, shield-ner, sycophancy-strip,
data-sovereignty-gate, prompt-injection-guard, confidentiality-sign.

### 2.2 Ratchet

`scripts/test-coverage-ratchet.sh`:

```text
test-coverage-ratchet.sh [--threshold N] [--ci]
  --threshold N   % mínimo de hooks críticos con BATS (default 100)
  --ci            exit 1 si cobertura < umbral
Exit: 0 ok · 1 FAIL · 2 usage
```

- Mide: hooks_criticos_con_bats / hooks_criticos.
- Reporta los hooks sin test (para generarlos incrementalmente).
- `--threshold` persistente en `config/test-coverage.conf`.

### 2.3 Tests TS (documentación)

Añadir a `.opencode/plugins/README.md` la sección "Cómo ejecutar los tests":
```bash
export PATH="$HOME/.savia/node/bin:$PATH"   # node 22
cd .opencode/plugins && bun install && bun test
```

## 3. Reglas de negocio

| ID | Regla | Incumplimiento |
|---|---|---|
| RN-01 | El ratchet es no-decreciente: nunca se baja el umbral para que CI pase | Test de umbral |
| RN-02 | Solo cuenta hooks críticos de la allowlist; el resto es advisory | Test de conteo |
| RN-03 | No genera tests automáticamente (CRIT-009: deuda se paga al tocar) | — |
| RN-04 | PURE_BASH; sin LLM, sin red (CRIT-001) | bash -n |

## 4. Criterios de aceptación

| AC | Criterio (falsificable) |
|---|---|
| AC-1 | `test-coverage-ratchet.sh --threshold 100 --ci` falla hoy (coverage < 100) |
| AC-2 | Al añadir BATS para un hook crítico, el ratio sube exactamente ese contador |
| AC-3 | `README` de plugins documenta el comando bun test |
| AC-4 | 3 BATS: conteo, umbral no-decreciente, detección de hook sin test |

## 5. Fuera de alcance

- Escribir todos los BATS (se hace por slices según disponibilidad).
- Migrar tests TS a node:test.

---

## Anclaje

- Deuda: `docs/technical-debt-2026-08-23.md` §2.1.
- Labs: L14 (hypothesis `l14-circuit-closing`).
- Regla: SE-046 (baseline metrics), SE-167.