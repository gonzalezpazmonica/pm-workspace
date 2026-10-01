---
status: PROPOSED
priority: P2
developer_type: agent-single
created: 2026-10-01
author: Savia
phase: A
risk: L2
related_specs: [SE-407, SE-258, SE-422]
origin: SE-407 S4 (docs/evidence/SE-407-S4-audit-harness-20261001.md), hueco real «dependency lockfile»
resource: https://github.com/gonzalezpazmonica/savia/blob/main/.gitignore
---

# SE-425 — Lockfiles de npm versionados e instalación reproducible

## Problema

`.gitignore` excluye `**/package-lock.json` en todo el repo:

- La CI instala las dependencias de `scripts/` con `npm install`. Las versiones de primer
  nivel están fijadas, pero las transitivas se resuelven en cada ejecución. El job
  «Dependency Audit» genera un lock efímero para poder auditar.
- `projects/savia-vaults` es un producto open source con 738 tests y no versiona su lock:
  dos instalaciones de la misma versión pueden traer dependencias distintas.
- La suite de savia-vaults no se ejecuta en ningún workflow de CI; solo en local.

## Objetivo

Instalaciones reproducibles donde importa, sin tocar lo que no lo necesita.

## Solución

1. `.gitignore`: dejar de ignorar los lockfiles en `scripts/` y `projects/savia-vaults/`;
   el resto sigue igual hasta que se decida.
2. Versionar `scripts/package-lock.json` y `projects/savia-vaults/package-lock.json`,
   generados con la versión de npm de la CI (Node 20 y 22 respectivamente).
3. CI: `npm ci --prefix scripts` en lugar de `npm install`; el job de auditoría usa el
   lock versionado (sin `--package-lock-only`).
4. Opcional (decisión D1): job de CI para savia-vaults con `npm ci`, `tsc`, `eslint` y
   `vitest` (Node 22; ~2 min). Los tests que necesitan ClamAV, el extractor o Ollama ya
   se omiten sin ellos.
5. `validate-ci-local.sh`: aviso si `package.json` cambia sin su lock.

## Decisiones abiertas

- **D1**: añadir el job de CI de savia-vaults en esta spec (recomendado) o aparte.
- **D2**: ampliar a `savia-web` y `savia-monitor` ahora o cuando se toquen.

## Criterios de aceptación

- **AC1**: `npm ci` en `scripts/` y en `projects/savia-vaults/` instala exactamente el lock
  versionado; un `package.json` modificado sin regenerar el lock hace fallar `npm ci`.
- **AC2**: la CI usa `npm ci` y el job de auditoría audita el lock versionado.
- **AC3** (si D1): el job de savia-vaults pasa en CI con la suite completa sin servicios
  externos.
- **AC4**: el ratchet de entropía y `validate-ci-local.sh` siguen en verde.

## Entregables (rutas)

- `.gitignore`, `scripts/package-lock.json`, `projects/savia-vaults/package-lock.json`
- `.github/workflows/ci.yml`, `scripts/validate-ci-local.sh`, `tests/test-validate-ci-fresh.bats`

## Fuera de alcance

Actualizar dependencias o cambiar de gestor de paquetes. Python ya usa
`requirements.lock` con hashes (SE-416).

## OpenCode Implementation Plan

### Bindings touched

Ninguno: configuración de npm y CI.

### Verification protocol

- [ ] `npm ci` limpio en ambos directorios y CI en verde.

### Portability classification

- [x] **PURE_BASH**
