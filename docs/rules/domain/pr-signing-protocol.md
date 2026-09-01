---
context_tier: L2
token_budget: 560
---

# PR Signing Protocol — Zero re-sign commits

> Evitar el bucle firma→commit→diff cambiado→firma invalida→re-firmar.

## El problema

`confidentiality-sign.sh sign` calcula hash del diff `origin/main..HEAD`.
Si haces commits despues de firmar, el diff cambia y la firma es invalida.
Resultado: commits extra de re-firma que ensucian el historial.

## Protocolo obligatorio (orden estricto)

```
1. TERMINAR todo el trabajo (codigo, docs, tests, CHANGELOG)
2. VERIFICAR CI local: bash scripts/validate-ci-local.sh
3. SI CI pide CHANGELOG → añadir CHANGELOG y commitear
4. FIRMAR: bash scripts/confidentiality-sign.sh sign
5. COMMIT de firma: git add .confidentiality-signature && git commit
6. PUSH: git push origin {rama}
7. CREAR PR

NUNCA hacer commits de contenido despues del paso 4.
```

## Regla clave

**La firma es SIEMPRE el ultimo commit de la rama antes de push.**
Si necesitas hacer cambios despues de firmar:
1. Hacer el cambio
2. Commitear
3. Re-firmar (paso 4-6)

No hay forma de evitar re-firmar si cambias contenido. Lo que se evita
es firmar demasiado pronto (antes de tener todo listo).

## Checklist pre-PR (para Savia)

Antes de crear PR, verificar en este orden:
- [ ] CI local pasa (validate-ci-local.sh)
- [ ] CHANGELOG tiene entrada si hay cambios en rules/hooks/agents/skills
- [ ] CHANGELOG tiene link comparativo al final
- [ ] Todo commiteado (git status limpio salvo .confidentiality-signature)
- [ ] Firmar: `bash scripts/confidentiality-sign.sh sign`
- [ ] Commit firma: `git add .confidentiality-signature && git commit`
- [ ] Push
- [ ] Crear PR (nunca draft si se va a mergear pronto)

## Script wrapper: push-pr.sh

`scripts/push-pr.sh` automatiza los pasos 2-7:
```
push-pr.sh [--title "titulo"] [--body "body"]
```
Ejecuta CI → firma → commit → push → crea PR. Un solo comando.

## Anti-patterns

- Firmar antes de tener el CHANGELOG → PR Guardian rechaza → re-firmar
- Hacer commit de firma junto con otros cambios → confuso en historial
- Push sin firmar → CI falla → commit extra de firma

## Lecciones operativas (sesión 2026-08-31, specs SE-352..364)

Las tres lecciones son complementarias: la #1 es la causa raíz (ya arriba), la
#2 y #3 son adiciones de proceso aprendidas al mergear 9 specs en una sesión.

1. **Firma atómica** (ya cubierto arriba): usar `push-pr.sh` o el flujo de
   `/pr-plan` que firma+push en un solo paso. Evitar `git push` manual tras
   firmar — cada push manual invalida `.confidentiality-signature` y dispara
   el ciclo de re-firma. Si se usa push manual, re-firmar SIEMPRE justo antes
   del push final y verificar con `confidentiality-sign.sh verify`.

2. **Regenerar SCM y rules INDEX ANTES de lanzar `/pr-plan`** (gates G5b y
   SE-097): cada script o regla nueva añadido al repo hace stale a
   `.scm/INDEX.scm` y `docs/rules/INDEX.md`. Regenerar proactivamente:
   ```bash
   python3 scripts/generate-capability-map.py
   bash scripts/rules-index-generate.sh
   ```
   ANTES de ejecutar pr-plan evita un ciclo de "G5b FAIL → regenerar → re-run".
   El check existe (SPEC-SCM-FRESHCHECK); la lección es hacerlo primero.

3. **Job "Lint Markdown" se cuelga en algunos runs de CI**: el job de Lint a
   veces queda en `pending` indefinidamente sin completar, bloqueando el merge
   aunque los 16 checks importantes pasen. Mitigación: un re-push (re-firmar +
   push) fuerza un run fresco que completa el Lint. Verificar con
   `gh pr view {n} --json mergeStateStatus` — si `CLEAN` aunque el Lint siga
   listado, el merge funcionará.

## Referencias

- Rule #25: `docs/rules/domain/critical-rules-extended.md`
- `SPEC-SCM-FRESHCHECK.spec.md` (gate G5b), `rules-index-generate.sh` (SE-097)
