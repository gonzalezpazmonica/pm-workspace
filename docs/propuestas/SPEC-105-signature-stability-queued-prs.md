---
spec_id: SPEC-105
title: Stable confidentiality signatures across queued PRs
status: Implemented
origin: Production incident (2026-04-15) — PR queue signature failures
severity: Alta
effort: ~3h
---

# SPEC-105: Signature stability across queued PRs

## Problema

Cuando PR B está en cola detrás de PR A, al mergear A ocurren dos fallos:

1. **Hash inválido**: `confidentiality-sign.sh` usa `git diff origin/main..HEAD`.
   Tras merge de A, `origin/main` avanza. El hash de B (firmado cuando main
   era más antiguo) ya no coincide con el diff recomputado en CI → fallo de
   verificación de firma.

2. **Merge conflict en `.confidentiality-signature`**: cada PR escribe su
   propia firma en ese fichero. Cuando B rebasa sobre el nuevo main (que
   tiene la firma de A), git reporta conflicto.

Ambos problemas juntos hacen que cada merge rompa al siguiente PR en cola
y obliguen a intervención manual (rebase + resolve + resign + push).

## Solucion

Tres cambios coordinados:

### 1. Hash basado en `merge-base` (estable)

`scripts/confidentiality-sign.sh` cambia:

```bash
# ANTES (inestable — origin/main se mueve)
git diff origin/main..HEAD

# DESPUES (estable — merge-base no cambia al avanzar main)
base=$(git merge-base origin/main HEAD)
git diff "$base..HEAD"
```

`merge-base` es el ancestro común de branch y main. Solo cambia si la
branch rebasa sobre nuevos commits — que es exactamente el caso donde
resignar es legítimo.

### 2. `.gitattributes` auto-resolve de conflictos en signature

```
.confidentiality-signature merge=ours
```

Al rebasar, git descarta la firma de main y conserva la del branch. CI
verifica inmediatamente después contra el hash (estable con merge-base).

### 3. `scripts/pr-rebase.sh` como helper

Script que encapsula el flujo correcto:
1. `git fetch origin main`
2. `git rebase origin/main`
3. Si conflicto solo en `.confidentiality-signature` → resolver (ours) auto
4. Re-sign con merge-base actualizado
5. Commit firma + `git push --force-with-lease`

Uso:
```bash
bash scripts/pr-rebase.sh            # rebase + resign + push
bash scripts/pr-rebase.sh --no-push  # local only
```

Si hay conflictos más allá de signature → abort con instrucción clara.

## Flujo antes vs después

**ANTES:**
```
PR A merge → main avanza
PR B CI falla (hash stale)
Dev manual: fetch + rebase + resolve conflict + resign + push
~10 min por PR en cola
```

**DESPUES:**
```
PR A merge → main avanza
Dev ejecuta: bash scripts/pr-rebase.sh
Script: fetch + rebase + auto-resolve + resign + push
~30 seg sin intervención
```

## Criterios de aceptacion

- [x] `confidentiality-sign.sh` usa merge-base en lugar de origin/main
- [x] `.gitattributes` añade `.confidentiality-signature merge=ours`
- [x] `scripts/pr-rebase.sh` con fetch/rebase/resolve/resign/push
- [x] Tests BATS >= 10 casos (test-pr-rebase.bats)
- [x] Documentado en pr-signing-protocol.md

## Restricciones

- **SIG-STAB-01**: Si la branch se rebasa sobre nuevos commits reales (no
  solo avance lineal), el merge-base cambia y hay que resignar. Este es
  el comportamiento correcto.
- **SIG-STAB-02**: `--force-with-lease` (no `--force`) para que no se pisen
  cambios remotos nuevos.
- **SIG-STAB-03**: Si hay conflictos fuera de signature → abort automático.
  Nunca resolver conflictos de código automáticamente.
- **SIG-STAB-04**: El script asume `origin/main` como tronco. No configurable
  (simplicidad).

## Regresión guard

Añadir a pre-commit check o BATS:
- Verificar que `scripts/confidentiality-sign.sh` contiene `merge-base`
- Verificar que `.gitattributes` contiene `.confidentiality-signature merge=ours`

## Out of scope

- Firma en git notes (arquitectura más limpia pero cambio masivo)
- CI auto-rebase (riesgo: pisa cambios locales del dev)
- Signature sobre tree state en lugar de diff (otra arquitectura)

## Historial del incidente

- 2026-04-15 PR #565 mergea → PR #567 CI verde pero mergeable=CONFLICTING
  por signature
- 2026-04-15 PR #566 mergea → #567 sigue conflicting, requiere rebase
- Root cause analysis lleva a SPEC-105

## Referencias

- `scripts/confidentiality-sign.sh`
- `.gitattributes`
- `scripts/pr-rebase.sh`
- `docs/rules/domain/pr-signing-protocol.md`
- Commit history de conflictos: buscar "sign confidentiality audit" en log
