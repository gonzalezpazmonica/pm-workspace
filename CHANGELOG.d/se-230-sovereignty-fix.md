## Fix: sovereignty-patterns.ts — paths relativos docs/ bloqueados incorrectamente

Fixed: N1_DEST_RX regex no matcheaba paths relativos sin slash inicial (docs/propuestas/,
docs/rules/domain/). Ollama clasificaba como AMBIGUOUS y bloqueaba en lugar de WARN.
Solución: añadir ^docs\/ al regex. 15 tests TDD verifican el fix.
