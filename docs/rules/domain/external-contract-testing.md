---
context_tier: L2
token_budget: 574
---

# External Contract Testing

> Trabajo derivado de SPEC-155 (silent security regression detectada 2026-05-30 tras migración OpenCode v1.14+).

## Regla

Todo módulo que dialoga con un sistema externo (frontend de agente, API de terceros, plugin runtime) DEBE tener al menos un integration test que use la shape documentada del sistema externo, copiada literalmente de su doc oficial. El test debe romperse si el sistema externo cambia el contrato.

## Por qué

Tests unitarios que emulan la shape interna asumida pasan aunque el contrato externo cambie. Esto produce silent regression: el código sigue compilando y los tests verdes, pero los hooks/guards operan sobre payloads vacíos en producción.

Caso SPEC-155: guards leían `input.args` (asunción interna), pero OpenCode v1.14+ entrega los args en `output.args`. Tests pasaban porque pasaban `{ args }` en `input` y `{}` en `output`. Guards de seguridad (validate-bash-global, credential-leak, data-sovereignty-gate) operaron como security theater durante días sin detectarse.

## Cómo

1. Identificar la shape oficial del sistema externo (URL de su doc + sección).
2. Copiar literalmente esa shape en una constante `EXTERNAL_CONTRACT_SHAPE` al inicio del test file.
3. Crear al menos un test por path crítico (guard, hook, transformación) que use esa shape exacta.
4. El test debe fallar de forma evidente (no silenciosa) si el sistema externo cambia el contrato.

## Aplicado en

- `.opencode/plugins/__tests__/savia-foundation.test.ts` (tests `SPEC-155: v1.14 shape — …`).
- `.opencode/plugins/lib/hook-input.ts` (header con cita literal del contrato OpenCode v1.14+).

## No reemplaza

- Tests unitarios de lógica pura (siguen siendo válidos para algoritmos sin dependencia externa).
- Auditoría manual post-migración a nueva versión del frontend (recomendado además del integration test).

## Detección activa de silent failure

Guards que devuelven `return` silencioso ante input vacío son bug, no feature. Añadir warning log cuando un guard se ejecuta pero no encuentra el campo esperado, salvo que el skip sea explícito por contrato (ej. tool fuera del scope).

## Referencias

- SPEC-155 — Plugin hook args shape fix
- Rule #22 Verification Before Done
- OpenCode plugins: https://opencode.ai/docs/plugins/
