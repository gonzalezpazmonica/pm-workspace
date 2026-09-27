---
bump: patch
section: Fixed
---

- Restaurado `scripts/validate-handoff.sh` (SPEC-TERMINAL-STATE-HANDOFF, interfaz `--file` de `agent-handoff-protocol.md`), sobrescrito por SE-387 en #1094. El validador de integridad F3 de SE-387 pasa a `scripts/validate-handoff-integrity.sh`, ahora con tests propios.
