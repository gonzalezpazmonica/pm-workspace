---
version_bump: patch
section: Added
---

### Added

- SE-352 Trust-Gated Memory: cada entrada de memoria lleva `origin` (owner/agent/untrusted/system), fail-safe a `untrusted` sin fuente confiable; taint de turno tras tools de red (hook `memory-origin-gate.sh`); `memory-store.sh consolidate` excluye `untrusted`/`system` de la promoción; filtro `search --min-origin` y `audit-origins`.
