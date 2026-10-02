---
status: PROPOSED
priority: P1
developer_type: agent-single
created: 2026-10-02
author: Savia
phase: A
risk: L2
related_specs: [SPEC-111, SPEC-188, SE-314]
origin: "Decisión de la operadora 2026-09-27: «Firma → secreto de CI + HMAC siempre verificado (la operadora crea el secreto)». Handback hmac-signature-ci-20260927"
resource: https://github.com/gonzalezpazmonica/savia/blob/main/scripts/confidentiality-sign.sh
---

# SE-426 — Firma de confidencialidad con secreto de CI y HMAC siempre verificado

## Problema

`scripts/confidentiality-sign.sh` firma el hash del árbol con HMAC-SHA256 y una clave
local (`~/.savia/confidentiality-key`):

- **La CI no tiene la clave.** «Verify Audit Signature» solo comprueba el hash del árbol y
  avisa `HMAC: SKIPPED`. Cualquiera que calcule el hash puede escribir una firma que pasa.
- **Las firmas del bot no valen nada.** Los workflows que re-firman (`auto-rebase-open-prs`,
  `changelog-consolidate`) crean una clave efímera en el runner. Esas firmas no se pueden
  verificar con ninguna clave.
- **La clave sale en argv.** `openssl dgst -hmac "$key"` deja la clave en la línea de
  comandos, visible con `ps`.

## RCA del handback (hmac-signature-ci-20260927)

El 27/09 el agente nocturno escribió 7 tests (en rojo) en
`tests/scripts/test-confidentiality-sign.bats`, rama `agent/hmac-signature-ci-20260927`.
Al implementar, el `data-sovereignty-gate` bloqueó la edición tres veces con
`classifier_confidential_high_confidence`. Fue un falso positivo de qwen2.5:3b, que #1162
corrigió después: «confidencial» exige ahora citar el dato.

Comprobado el 2026-10-02:

- El script completo candidato clasifica `public` (0,5) → ALLOW, 3 de 3.
- Los fragmentos tipo `Edit` clasifican `ambiguous` (0,6) → WARN, que en N1 deja pasar.
- La candidata pasa los 27 tests de esa rama.

## Solución

Despliegue en tres pasos, en este orden: exigir el HMAC antes de que exista el secreto
bloquearía todos los PR.

1. **Código y tests, sin cambios en la CI.**
   - **Clave:** `CONFIDENTIALITY_HMAC_KEY` si no está vacía; si no, el fichero local. Vacía
     cuenta como ausente.
   - **Modo exigente:** con `CONFIDENTIALITY_REQUIRE_HMAC=1`, `sign` no crea una clave
     efímera y `verify` falla cerrado si no hay clave.
   - **Cálculo:** el HMAC se calcula con la clave por stdin, nunca en argv. Da el mismo
     resultado que `openssl -hmac`, así que las firmas existentes siguen verificando.
2. **Secreto de CI (operadora).** `CONFIDENTIALITY_HMAC_KEY` en el repo, con el mismo valor
   que la clave local, para que la firma local y la verificación en CI se entiendan.
3. **Workflows.**
   - `confidentiality-gate.yml` (verify) y los dos workflows que re-firman reciben el secreto.
   - Los tres exigen `CONFIDENTIALITY_REQUIRE_HMAC=1`.
   - Tras este paso, una firma sin la clave correcta no pasa la CI.

## Criterios de aceptación

- **AC1**: el HMAC es HMAC-SHA256(clave, diff_hash), y la clave no aparece en ningún argv.
- **AC2**: la clave de CI y la local con el mismo valor son intercambiables. Una firma hecha
  con otra clave da `HMAC mismatch`.
- **AC3**: con `CONFIDENTIALITY_REQUIRE_HMAC=1` y sin clave, `sign` no escribe firma ni crea
  clave y `verify` falla nombrando `CONFIDENTIALITY_HMAC_KEY`. Sin la variable, el
  comportamiento local no cambia.
- **AC4**: una firma existente (hecha con `openssl -hmac`) sigue verificando.
- **AC5** (paso 3): un PR con firma sin la clave correcta falla «Verify Audit Signature», y
  un PR re-firmado por el bot pasa.
- **AC6**: los 27 tests BATS en verde, con auditor ≥ 80.

## Entregables (rutas)

- `scripts/confidentiality-sign.sh`, `tests/scripts/test-confidentiality-sign.bats`
- Paso 3: `.github/workflows/confidentiality-gate.yml`, `.github/workflows/auto-rebase-open-prs.yml`,
  `.github/workflows/changelog-consolidate.yml`

## Riesgo

- **Orden del despliegue.** Activar el paso 3 sin el secreto bloquea todos los PR. El
  paso 3 se hace solo después de comprobar que el secreto existe con `gh secret list`.
- **Alcance de la protección.** Quien tenga acceso de usuario al host de la operadora puede
  firmar, como con toda clave local. El secreto protege frente a firmas hechas sin la clave,
  no frente a un host comprometido.

## Fuera de alcance

Firmas con clave asimétrica, rotación automática de la clave y firma por commit.

## OpenCode Implementation Plan

### Bindings touched

Ninguno: script de shell y workflows de CI.

### Verification protocol

- [ ] `bats tests/scripts/test-confidentiality-sign.bats` 27/27.
- [ ] Paso 3: un PR de prueba firmado con otra clave falla en CI; uno re-firmado por el bot pasa.

### Portability classification

- [x] **PURE_BASH**
