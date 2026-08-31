---
context_tier: L3
token_budget: 800
---

# Audit Non-Claims — SE-355

> Lo que el audit ledger de Savia **no** garantiza. Honestidad estructural
> (Rule #24): publicar los límites es parte de la auditoría, no un disclaimer.

## El ledger NO prueba

1. **Ausencia de fila ≠ ausencia de acción.** "No hay registro" puede significar
   que la acción ocurrió sin pasar por el ledger, que un hook falló, o que el
   pruning lo borró. El ledger es metadata de lo registrado, no un espejo del
   universo.
2. **Éxito ≠ autorización.** Un `outcome: success` con `enforced: false` es un
   hecho, no una prueba de que un gate lo aprobó. Solo `enforced: true` con
   `gate_id` registra una decisión gobernada.
3. **Pseudonimización ≠ anonimización.** El ledger guarda `actor` (slug), no PII,
   pero un actor + sesión puede ser correlacionable. No es anonimización.
4. **Retención 30 días ≠ garantía de borrado.** El pruning es batch y best-effort.
   No es borrado forense ni certificación de erasure.
5. **Metadata-only ≠ sin riesgo.** Que el ledger no guarde prompts/args no
   protege otros canales (logs de hooks, session logs). Cada superficie debe
   auditarse por separado.

## Lo que el ledger SÍ registra

- Identidad (actor), orden (seq monótono), acción (verbo cerrado), outcome
  (vocabulario cerrado), enforced (bool), gate_id.
- **Jamás**: prompts, bodies, argumentos, filenames, valores de secrets.

## Reglas de uso

- Un receipt con `enforced: false` **nunca** se promueve a prueba de
  autorización en informes, tribunales o auditorías.
- Las queries de "decisiones gobernadas" usan `audit-receipts.sh governed`
  (filtra `enforced: true`), nunca el ledger completo.
- Ante una duda de compliance, cita el límite exacto de esta página.

## Referencias

- SE-355: `docs/specs/SE-355-audit-ledger.spec.md`
- Inspiración: OpenClaw audit ledger (non-claims públicos)
- Savia: `radical-honesty.md` (Rule #24), `autonomous-safety.md`
