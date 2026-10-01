---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): arreglos H1, H2, H3 y H4 aprobados, un PR Draft por arreglo"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L2
related_specs: [SE-416, SE-419, SE-421, SE-422, SE-423]
origin: revisión S02 de Vaults/Files (docs/evidence/S02-vaults-files-review-20260930.md), hallazgos H1–H4
resource: https://github.com/gonzalezpazmonica/savia/tree/main/projects/savia-vaults/src
---

# SE-424 — SaviaVaults/Files: arreglos de la revisión S02 (escaneo > 2 GiB, A2A, revocación en MCP, modelos del lector de PDF)

## Problema

La revisión S02 (2026-09-30) encontró, con procesos reales, cuatro fallos que la suite no
detectaba. Evidencia completa en `docs/evidence/S02-vaults-files-review-20260930.md`.

| # | Fallo | Consecuencia |
|---|---|---|
| H1 | ClamAV no analiza más de 2 GiB − 1 por fichero y responde «OK» (código 0) | Con `scan: required`, un fichero de 2–10 GiB (SE-421/422) se guarda como limpio sin analizar |
| H2 | A2A sin token sirve cualquier cúpula (N4 incluida), rutas absolutas y `Access-Control-Allow-Origin: *`; `--host` no se valida | Cualquiera en la red, o una web en el navegador, lee las cúpulas |
| H3 | El servidor MCP carga los usuarios una vez | `user revoke`/`delete` no afectan a un proceso MCP abierto |
| H4 | `files setup` no descarga los modelos de docling y el worker va offline | En una máquina limpia todos los PDF quedan `FAILED` |

## Solución

### H1 — Escaneo que no cubre el fichero entero falla cerrado (`src/files/scan.ts`)

- `--alert-exceeds-max=yes` en todas las llamadas a `clamscan` (ruta y stdin). ClamAV
  marca `Heuristics.Limits.Exceeded.*` y termina con código 2.
- Antes de lanzar ClamAV, si el tamaño es ≥ 2 GiB − 1:
  - `scan: required` ⇒ rechazo `SCAN_REQUIRED` con motivo `too-large-to-scan` (sin blob
    ni temporales). En HTTP (tus), la creación con `Upload-Length` por encima da 422 con
    ese motivo, antes de recibir bytes.
  - `scan: optional` ⇒ se guarda con `scan: { status: "skipped", reason: "too-large-to-scan" }`,
    visible en `show`, `list` y en el MCP.
- Un `Heuristics.Limits.Exceeded` inesperado (p. ej. límites internos de archivos
  comprimidos) se trata igual que «no analizado».

### H2 — Guarda de A2A (`src/server/a2a.ts`, `src/cli/main.ts`)

- Fuera de loopback, A2A no arranca sin `SAVIA_VAULTS_TOKEN`, con un mensaje llano.
- Sin token, solo sirve cúpulas N1/N2; las N3/N4 no aparecen ni en `/domes` ni en
  búsquedas ni en lecturas.
- Token comparado en tiempo constante (`timingSafeEqual` sobre SHA-256).
- Sin `Access-Control-Allow-Origin: *`. `SAVIA_A2A_CORS_ORIGINS` (lista explícita) es
  opcional; sin ella no hay cabeceras CORS.
- `/domes` sin `path`.
- El modelo por usuario y el PDP común llegan con SE-423; esto es la guarda mínima.

### H3 — Revocación en caliente en MCP (`src/server/mcp.ts`)

- `authorize` llama a `userStore.reloadIfChanged()` antes de decidir. Si el fichero no
  existe y antes existía, se deniega todo.
- Coste medido: `stat` por llamada, y bcrypt solo al cambiar el fichero o al validar.

### H4 — Modelos del lector de PDF (`src/files/setup.ts`, `src/files/extract.ts`)

- `files setup` descarga `layout` y `tableformer` con
  `python -m docling.cli.tools models download layout tableformer -o <tools>/docling-models`
  (unos 506 MiB), con reintento y verificación. Para verificar, se escribe un manifiesto
  SHA-256 por fichero la primera vez, y `status` lo comprueba.
- El worker recibe `artifacts_path=<tools>/docling-models` (variable
  `SAVIA_FILES_DOCLING_MODELS`) y sigue offline.
- `files status` dice «faltan los modelos del lector de PDF» y `files setup` los completa
  (idempotente: una segunda ejecución descarga 0 bytes).
- Los documentos `FAILED` por este motivo se recuperan con `files reprocess`; `status` lo
  indica.

## Criterios de aceptación

- **AC1 (H1)** Con una firma de prueba `.ndb` y un stream de más de 2 GiB con el marcador en
  el byte 0: `scan: required` ⇒ `SCAN_REQUIRED`/`too-large-to-scan`, sin blob;
  `optional` ⇒ guardado con `skipped`. En tus, 422 al crear. Por debajo de 2 GiB, el
  marcador se detecta (`QUARANTINED`). Con ClamAV gestionado real.
- **AC2 (H2)** `--host 0.0.0.0` sin token ⇒ no arranca (test del proceso, sin escuchar).
  Sin token en loopback, una cúpula N4 no aparece en `/domes`, `/search` ni lectura; N2
  sí. No hay `Access-Control-Allow-Origin` por defecto. `/domes` sin rutas. Token
  incorrecto de la misma longitud ⇒ 401.
- **AC3 (H3)** Cliente MCP real (stdio): permitido → `user revoke` ⇒ denegado en la
  siguiente llamada; `user delete` ⇒ `Invalid or expired token`; sin reiniciar.
- **AC4 (H4)** `files setup` en un HOME y `SAVIA_TOOLS_HOME` vacíos (sin caché de
  HuggingFace) ⇒ `contrato.pdf` `READY` con cita de página. Segunda ejecución: 0 bytes.
  Un modelo manipulado ⇒ `status` lo marca y `setup` lo repara.
- **AC5** Suite completa en verde; `docs/files.md`, `docs/files-http.md` y la skill
  actualizados.

## Entregables (rutas)

- `projects/savia-vaults/src/files/scan.ts`, `projects/savia-vaults/src/files/service.ts`,
  `projects/savia-vaults/src/server/tus.ts`
- `projects/savia-vaults/src/server/a2a.ts`, `projects/savia-vaults/src/cli/main.ts`
- `projects/savia-vaults/src/server/mcp.ts`
- `projects/savia-vaults/src/files/setup.ts`, `projects/savia-vaults/src/files/extract.ts`,
  `projects/savia-vaults/workers/files/extract.py`
- `projects/savia-vaults/tests/unit/files/scan.test.ts`,
  `projects/savia-vaults/tests/integration/files/scan-limits.test.ts`,
  `projects/savia-vaults/tests/integration/server/a2a-guard.test.ts`,
  `projects/savia-vaults/tests/e2e/mcp-revocation.test.ts`,
  `projects/savia-vaults/tests/unit/files/setup.test.ts`
- `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/docs/files-http.md`

## Esfuerzo

Agente ~8 h (H1 2 h, H2 2 h, H3 1 h, H4 3 h); revisión humana ~1 h por PR.
Un PR Draft por arreglo, en este orden: H1, H2, H3, H4.

## Fuera de alcance

El modelo de identidad (Subject, credenciales, PDP): SE-423. Analizar ficheros de más de
2 GiB por trozos, que no es fiable con firmas que cruzan el corte. OCR.

## OpenCode Implementation Plan

### Bindings touched

Solo `projects/savia-vaults` (TypeScript/Node y worker Python). Nada del workspace.

### Verification protocol

- [ ] H3 con cliente MCP real en Claude Code y OpenCode.
- [ ] H4 en un HOME limpio real.

### Portability classification

- [x] **PURE_NODE** (H4 usa el worker Python ya existente, sin bindings de frontend)

## Resultados

### H2 (2026-09-30)

| AC | Evidencia | Estado |
|---|---|---|
| AC2 | `a2a-guard.test.ts` (4): con host no-loopback (TEST-NET 192.0.2.1) y sin token, no arranca ni el servidor ni la CLI (código 1); sin token en loopback, N4 ausente de `/domes`, `/search`, `/context` y `/share`, y N2 accesible; sin `Access-Control-Allow-Origin`; `Origin` ajeno ⇒ 403 en lectura y en escritura `text/plain`; origen permitido con eco; token de igual longitud distinto ⇒ 401. Sonda real repetida (CLI, loopback, N4): `{"results":[]}` y `{"domes":[]}` | OK |

Desviaciones:

1. **Peticiones con `Origin`** (navegador) se rechazan salvo lista explícita. La spec solo
   pedía quitar `CORS *`; sin esto, una web podía escribir por `POST /share` con
   `text/plain`, que no provoca preflight. Clientes sin navegador (CLI, federación, curl)
   no envían `Origin` y no cambian.
2. **TLS**: A2A no tiene TLS propio y la documentación de federación decía lo contrario;
   se corrige `projects/savia-vaults/docs/FEDERATION.md`. Exigir TLS o proxy fuera de loopback queda para SE-423.
