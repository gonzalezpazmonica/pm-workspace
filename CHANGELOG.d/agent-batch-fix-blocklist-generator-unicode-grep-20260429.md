---
version_bump: patch
section: Fixed
---

## [6.23.1] — 2026-04-29

Hotfix workspace — `scripts/generate-blocklist.sh` ignoraba silenciosamente las exclusiones whitelist de `.gitignore` por classification de binary del propio `.gitignore`. Detectado durante revisión de PR externo (#729 fix savia-monitor cross-platform): pipelines del fork fallaban en `PII & Confidentiality Scan` porque el blocklist incluía `savia-monitor` aunque `.gitignore` declarara `!projects/savia-monitor/`.

### Fixed

#### `scripts/generate-blocklist.sh`

- Añade `-a` a `grep -oE '!projects/...'` para forzar text mode al leer `.gitignore`. El fichero contiene caracteres Unicode box-drawing (U+2500 `─`) en headers de comentarios, lo que hacía que GNU grep clasificara el archivo como binary y silenciosamente descartara las matches (sin error, exit 0, stdout vacío). Resultado: `PUBLIC_PROJS` quedaba vacío, los proyectos whitelisted se filtraban a la blocklist como falsos positivos, y cualquier PR externo (especialmente forks) que mencionara `savia-monitor` / `savia-web` / `savia-mobile-android` en CHANGELOGs o commits fallaba el `PII & Confidentiality Scan` con `BLOCKED: Blocklist terms found`.
- Comment inline explicando el porqué del `-a` para prevenir regresión por re-formato del script.

#### Tests de regresión

- `tests/structure/test-generate-blocklist.bats` — 12 tests cubriendo:
  - Identidad del script (shebang, executable, `set -uo pipefail`)
  - Regression test específica: el `-a` flag DEBE estar presente en el grep sobre `.gitignore`
  - Behavioral: cada `!projects/X/` whitelisted en `.gitignore` está EXCLUIDO del blocklist output
  - Behavioral: los proyectos NO whitelisted (privados) SÍ aparecen en blocklist
  - Edge: missing `.gitignore` degrada graceful sin crash
  - Spec ref: documenta PR #729 como root cause

### Why this matters

Un fork PR que cumpla todos los gates (test fix, sign, CHANGELOG, conventional commits) seguía fallando por un bug de 1 carácter en el blocklist generator. La huella era invisible — `grep` reportaba "binary file matches" en stderr durante el run del workflow pero no interpreté ese mensaje como una falla silenciosa hasta investigar el root cause directamente. El `-a` flag fix se aplica a 6 proyectos whitelisted (proyecto-alpha, proyecto-beta, sala-reservas, savia-mobile-android, savia-web, savia-monitor) y a cualquier futuro proyecto que se añada a `.gitignore` como exclusión.

### Spec ref

PR #729 (`pabloguti/pm-workspace#fix/savia-monitor-macos-pid-detection`) — fork PR externo que destapó el bug. Tras este hotfix, el contributor puede rebase su rama sobre main y los checks pasan sin más cambios.
