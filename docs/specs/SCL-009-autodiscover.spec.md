# SCL-009 — Auto-descubrimiento de instancias federadas (registro automático)

**Status:** APPROVED (operadora, 2026-08-22) → IMPLEMENTED 2026-08-22
**Fecha:** 2026-08-22
**Area:** Memoria / Federación / SaviaVaults A2A (SCL-007)
**Origen:** Labs L5 · backlog SCL (prioridad 3)
**Developer Type:** agent-single
**Context risk:** low
**Estimación:** agente ~6h / revisión humana 30min

---

## 1. Problema y objetivo

SCL-007 permite compartir/buscar lecciones entre instancias, pero exige pasar
la URL remota a mano (`--to <url>` / `--search-remote --url <url>`). Cuando hay
varias instancias, mantener su lista y su disponibilidad a mano es frágil:
una instancia caída provoca timeouts sin aviso.

SaviaVaults ya tiene el `FederationRegistry` (federation.json con id/url/status)
y `healthCheckAll()` (projects/savia-vaults/src/federation/). El objetivo:
(1) un script bash que registre instancias y detecte su salud via `/health`, y
(2) `learning-federate.sh` que use el registro para no exigir la URL a mano.

## 2. Contratos

### 2.1 `scripts/federation-discover.sh`

```text
federation-discover.sh [--pool FILE] [--check] [--add ID URL] [--remove ID] [--list]
  --pool FILE   fichero con candidatas (una por línea: id,url[,token])
                default: config/federation-pool.txt
  --add ID URL  registra una instancia en el registry (vía federation.json)
  --remove ID   la elimina del registry
  --list        lista instancias con su estado
  --check       health-checkea todas las registradas via /health y actualiza status
Exit: 0 ok · 2 input inválido · 3 dependencia ausente
```

El script lee/escribe `projects/savia-vaults/config/federation.json` (el mismo
que consume el `FederationRegistry` de SaviaVaults).

### 2.2 Integración con `learning-federate.sh`

- `--search-remote --query q` sin `--url`: usa la primera instancia `healthy`
  del registry (o exige `--url` si no hay ninguna).
- `--share <id>` sin `--to`: igual, usa la primera `healthy`.

### 2.3 Política de salud

- `/health` con respuesta `ok` y estado 200 → `healthy`.
- timeout (≤ 3s) o no 200 → `unhealthy`.
- El registry guarda `status` y `lastHealthCheck`.

## 3. Reglas de negocio

| ID | Regla | Incumplimiento |
|---|---|---|
| RN-01 | El descubrimiento solo toca `federation.json` (registry), nunca `CRITERIO.md`/CONSTITUCION/lecciones | Test de no-mutación |
| RN-02 | Instancia `unhealthy` nunca se usa como destino por defecto | Test con mock caído |
| RN-03 | Un pool vacío o sin instancias sanas → `--search-remote` SIN `--url` es error de uso | Test |
| RN-04 | Sin red fuera de los endpoints del pool (CRIT-001) · timeouts ≤ 3s | Test |
| RN-05 | Ningún token del pool se persiste en texto plano en el repo público; el pool es config local (gitignored) si lleva token | Test de contenido |

## 4. Criterios de aceptación

- [x] AC-01: `--add ID URL` registra la instancia y aparece en `--list`.
- [x] AC-02: `--check` marca `healthy` una instancia mock que responde /health ok.
- [x] AC-03: `--check` marca `unhealthy` una instancia caída (timeout).
- [x] AC-04: `learning-federate.sh --search-remote --query q` sin `--url` usa la instancia healthy del registry.
- [x] AC-05: sin instancias sanas, `--search-remote` sin `--url` → exit 2.
- [x] AC-06: hashes de CRITERIO.md/CONSTITUCION.md invariantes.
- [x] AC-07: suite BATS >= 10, incluyendo adversariales (no-mutación, timeout).

> Verificación 2026-08-22: `bats tests/test-scl-009-autodiscover.bats` 9/9,
> `bash -n` en ambos scripts, 0 vendor names, hashes fundacionales invariantes.
> Bug corregido en vuelo: Python 3.12 `urlopen(url, headers=...)` no acepta
> `headers` como kwarg — se usa `urllib.request.Request` (AC-02).

## 5. Ficheros

**Crear**: `scripts/federation-discover.sh` · `tests/test-scl-009-autodiscover.bats`

**Modificar**: `scripts/learning-federate.sh` (fallback a registry healthy;
retrocompatible: `--url` explícito sigue ganando)

**No tocar**: `projects/savia-vaults/src/federation/registry.ts` (ya existe),
CRITERIO/CONSTITUCION, plugins TS.

## 6. Riesgos y rollback

- **Pool mal configurado** → `<3s` timeouts y warning, nunca bloquea.
- **Registry compartido** → el script bash solo añade/actualiza status; no
  reescribe domes ajenos (`--remove` requiere id explícito).
- Rollback: eliminar script + revert del toque a `learning-federate.sh`.

## 7. OpenCode Implementation Plan

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Descubrimiento | `scripts/federation-discover.sh` (PURE_BASH) | Idéntico |
| Integración federate | `scripts/learning-federate.sh` (PURE_BASH) | Idéntico |

- [x] **PURE_BASH**: sin bindings de frontend.

## 8. Gate de aprobación

Aprobación humana explícita requerida. Antes del PR: `/pr-plan`, `.pr-summary.md`,
rama `agent/scl009-autodiscover`. Sin merge ni approve autónomos.

## Referencias

- SCL-007 federación (`docs/specs/SCL-007-federacion-crossdome.spec.md`).
- `projects/savia-vaults/src/federation/registry.ts` y `search.ts` (healthCheckAll).
- Labs L5 (`labs/protocols/l5-federation-epistemology.md`).
- CRIT-001 (local, timeouts acotados), CRIT-031 (no auto-activación).