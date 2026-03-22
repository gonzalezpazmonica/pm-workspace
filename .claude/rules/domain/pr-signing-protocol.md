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
