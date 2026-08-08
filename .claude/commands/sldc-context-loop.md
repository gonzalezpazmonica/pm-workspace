---
name: sldc-context-loop
description: Cerrar el ciclo de conocimiento tras un merge — alimenta las cupulas de SaviaVaults (specs/ADRs/releases) y ejecuta la compuerta de estandares (SE-311)
tier: core
---
# /sldc-context-loop

Cierra el ciclo de conocimiento de Savia Flow (SE-311).

## Uso

1. **Analizar** (dry-run, sin escribir):
   ```
   bash scripts/sldc-context-loop.sh --base origin/main --head HEAD --dry-run
   ```
2. **Alimentar las cupulas** (escribe en SaviaVaults):
   ```
   bash scripts/sldc-context-loop.sh --base origin/main --head HEAD --feed
   ```
3. **Pendientes** (si el vault fallo):
   ```
   bash scripts/sldc-context-loop.sh --list-pending
   bash scripts/sldc-context-loop.sh --flush-pending
   ```
4. **Compuerta de estandares** (validacion determinista del diff final):
   ```
   bash scripts/standards-compliance-gate.sh --json
   bash scripts/standards-compliance-gate.sh --report output/standards-gate.md
   ```

## Que hace

- Detecta specs, ADRs (docs/propuestas) y CHANGELOG.d tocados por el diff.
- Genera notas grounded con citacion de fuentes y las escribe en la cupula (A2A /share).
- Valida el resultado final contra los estandares (file-size, skill-audit, agent-schema, drift, rules, confid).
