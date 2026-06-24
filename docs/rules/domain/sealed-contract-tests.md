---
context_tier: L2
spec: SPEC-188-P3
status: ACTIVE
---

# Sealed Contract Tests

> SPEC-188 Fase 2. Tests en tests/contracts/ son invariantes del sistema:
> los agentes autonomos no pueden modificarlos sin aprobacion humana explicita.

## Por que existen

Los agentes que fallan contra un test critico pueden intentar arreglar el test
en lugar del codigo (anti-patron SDD). Los contract tests eliminan esa posibilidad.

## Que tests son contract

1. Lineas rojas de savia-ethical-principles.md
2. Invariantes de seguridad: block-force-push, confidentiality-sign, hook-pii-gate
3. Invariantes de permisos: permissions-wildcard-audit, validate-agent-permissions
4. AC de specs congeladas (anadir requiere [contract-add] + humano)

## Enforcement

Hook contract-test-guard.sh (PreToolUse Edit/Write):
- Lee .claude/contracts/allowlist.txt
- Si rama agent/* Y path en allowlist: BLOQUEADO (exit 2)
- Si rama humana: pass-through
- Si ultimo commit contiene [contract-change/add/remove]: bypass

## Bypass legitimo

El unico bypass desde agent/* es un commit con prefijo [contract-change].
Requiere revision humana obligatoria antes de merge.

## Estructura

tests/contracts/
  README.md
  test-block-force-push.bats         (symlink a tests/hooks/)
  test-confidentiality-sign.bats     (symlink a tests/scripts/)
  test-hook-pii-gate.bats            (symlink a tests/hooks/)
  test-permissions-wildcard-audit.bats
  test-validate-agent-permissions.bats

.claude/contracts/
  allowlist.txt    (lista canonica)

## Anadir un test a la allowlist

Solo por humano, PR con titulo [contract-add]:
  echo "tests/mi-test.bats" >> .claude/contracts/allowlist.txt
  git commit -m "[contract-add] seal mi-test — razon"

## Referencias

- Hook: .opencode/hooks/contract-test-guard.sh
- Allowlist: .claude/contracts/allowlist.txt
- Spec: docs/specs/SPEC-188-P3-sealed-contract-tests.spec.md
- Origen: SPEC-188 docs/propuestas/SPEC-188-root-cause-investigation-architecture.md
