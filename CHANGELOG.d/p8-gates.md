---
version_bump: patch
section: Fixed
---
- **SE-383 P8 (fixture fundador, resuelto)**: validate-bash-global.sh era worktree-unaware — bloqueaba commits legítimos en worktrees leyendo la rama del repo principal (incidente 2026-09-05). Fix: ENTRY_PWD capturado antes del sourcing de libs; worktree-aware con regla original preservada. Chaos suite 8/8 (P8 ahora verde, era rojo documentado).
- **Gates de coherencia**: scripts/coherence-gates.sh (negative-tests SE-377, chaos SE-383, entropía SE-380, debt-budget SE-376, eval-coverage SE-381) integrado en validate-ci-local.sh en modo advisory. Entropía 1617>1615 en WARN: la reducción neta llega con la curation wave 1 (propuestas en inventario SE-376, ejecución requiere decisión humana por capability — SE-380 RN-01).
