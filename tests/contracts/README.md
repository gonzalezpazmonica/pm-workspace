# tests/contracts/ — Sealed Contract Tests (SPEC-188-P3)

Este directorio contiene **tests fortaleza**: invariantes de comportamiento del sistema
que los agentes autónomos NO pueden modificar sin aprobación humana explícita.

## Qué son

Tests en `.claude/contracts/allowlist.txt` que representan:
- Líneas rojas de `savia-ethical-principles.md`
- Invariantes de seguridad (block-force-push, confidentiality-sign)
- Acceptance criteria de specs congeladas por el equipo

## Regla de modificación

Cualquier edición a un fichero en la allowlist desde una rama `agent/*` es
bloqueada por `contract-test-guard.sh` (PreToolUse hook).

Bypass legítimo:
```
git commit -m "[contract-change] reason..."
```
Requiere **revisión humana obligatoria** antes de merge.

## Ficheros sellados

Ver `.claude/contracts/allowlist.txt` para la lista canónica.

## Referencias

- SPEC-188-P3: `docs/specs/SPEC-188-P3-sealed-contract-tests.spec.md`
- Hook: `.opencode/hooks/contract-test-guard.sh`
- Precommitment: `docs/specs/SPEC-188-P3-precommitment.md`
