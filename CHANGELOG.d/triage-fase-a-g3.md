---
bump: patch
section: Fixed
---

- Triage de suites (Fase A, grupo 3): `test-coverage-ratchet.sh` (SE-339) permitía bajar el umbral por flag, no validaba `--threshold`, ejecutaba su conf con `source` y aplicaba `--conf` tarde; sus dos suites reescribían `config/test-coverage.conf` versionado (llegaba a quedar en 999). `deps-validate.sh` usaba `\s` en awk (mawk: siempre 0 upstream/downstream) y solo contaba el primer item de cada sección. `code-twin-sync-check.sh` acepta `--today` y su test ya no caduca con el calendario. El smoke de migración a OpenCode contaba 0 agentes porque un plugin escribe en stdout antes del JSON. `pre-push-bats-critical.sh` se relanzaba sin fin desde su propia suite. `learning-reconcile.sh` devolvía 3 en vez de 2 ante un error de uso. `test-workspace.sh --mock` exigía `node_modules`. Árbol de decisión de `social-networks` creado (lo referenciaba SE-385 sin existir). Tests sin red (`gh` simulado) y sin dependencia de `vaults/` o `networkx` no instalados.
