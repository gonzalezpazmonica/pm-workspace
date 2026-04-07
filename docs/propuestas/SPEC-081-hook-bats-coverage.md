---
spec_id: SPEC-081
title: Tests BATS dedicados para los 10 hooks criticos
status: Proposed
origin: Auditoria 2026-04-07 (M-001)
severity: Media
effort: ~2h agente
---

# SPEC-081: Tests BATS dedicados para los 10 hooks criticos

## Problema

La mayoria de hooks carecen de tests BATS unitarios dedicados. Aunque se
ejercitan indirectamente en CI, una regresion en un hook individual puede
pasar desapercibida sin test aislado que valide su comportamiento especifico.

## Solucion

Crear ficheros BATS para los hooks mas criticos:
1. data-sovereignty-gate.sh
2. tdd-gate.sh
3. plan-gate.sh
4. compliance-gate.sh
5. prompt-hook-commit.sh
6. block-project-whitelist.sh
7. block-infra-destructive.sh
8. agent-dispatch-validate.sh
9. scope-guard.sh (ya tiene — verificar cobertura)
10. block-gitignored-references.sh (ya tiene — verificar cobertura)

Cada test: minimo 3 casos (happy path, bloqueo esperado, edge case).

## Criterios de aceptacion

- [ ] Ficheros BATS creados para hooks sin cobertura
- [ ] Cada fichero tiene >= 3 test cases
- [ ] Todos pasan con `bash tests/run-all.sh`
- [ ] Score auditor de calidad >= 80 por suite
