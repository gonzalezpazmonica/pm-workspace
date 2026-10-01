---
status: APPROVED
approved_at: 2026-10-01
approval: "Operadora 2026-10-01 en chat (AskUserQuestion): 'Aprobar con job CI de vaults' (D1 sí; D2: web y monitor cuando se toquen)"
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

## Decisiones (operadora, 2026-10-01)

- **D1**: sí, el job de CI de savia-vaults entra en esta spec.
- **D2**: `savia-web` y `savia-monitor`, cuando se toquen (fuera de esta spec).

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
- `scripts/confidentiality-scan.sh` (excepción del email público del aviso `deprecated` de npm), `.claude/.project-authorizations`

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

## Resultados (2026-10-01)

| AC | Evidencia | Estado |
|---|---|---|
| AC1 | `scripts/package-lock.json` (127 paquetes) y `projects/savia-vaults/package-lock.json` (283) versionados; `npm ci` en copias limpias instala exactamente esos árboles; `npm ci` rechaza un `package.json` desfasado sin red (`tests/test-validate-ci-fresh.bats`) | OK |
| AC2 | `ci.yml`: `npm ci --prefix scripts` en «Validate» y «BATS»; «Dependency Audit» audita los dos locks versionados (sin `--package-lock-only`) | OK (verificación final en la CI del PR) |
| AC3 | Job `savia-vaults` (Node 22: `npm ci`, `tsc`, `eslint`, `vitest`). En local, copia limpia con `npm ci` y `HOME` vacío: 748 tests pasan y 11 se omiten (extractor y antivirus ausentes) | OK en local; CI del PR |
| AC4 | `validate-ci-local.sh` avisa (WARN, no bloquea) si un `package.json` no coincide con su lock; 13/13 BATS; sin scripts nuevos (ratchet de entropía) | OK |

Desviaciones:

1. **Lock de savia-vaults tomado del árbol ya instalado y probado** (`node_modules/.package-lock.json`
   más la entrada raíz), no resuelto de nuevo: así el lock fija exactamente las versiones con
   las que pasó la suite. `npm ci` confirma que está sincronizado con `package.json`.
2. **Lock de `scripts/` generado con npm 10.9.2 (Node 22)**, no con el npm de Node 20 de la CI.
   Ambos usan `lockfileVersion: 3`; `npm ci` en la CI lo valida.
3. El aviso de `validate-ci-local.sh` compara las dependencias declaradas (estático, sin red);
   un lock con el mismo `package.json` pero árbol incoherente lo detecta `npm ci` en la CI.
4. **G7 y hook de privacidad**: el escáner de confidencialidad bloqueaba `i@izs.me`, el aviso
   público que el registro de npm pone en versiones antiguas de `glob`. Se permite solo ese
   email (decisión de la operadora 2026-10-01); los lockfiles se siguen escaneando en busca
   de credenciales. El hook de privacidad leyó `!projects/savia-vaults/package-lock.json`
   como proyecto nuevo; la operadora lo autorizó en el chat («Si piblico»).
