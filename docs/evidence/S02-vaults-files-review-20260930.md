# S02 — Paquete de revisión Vaults/Files (SE-410–422)

Fecha: 2026-09-30 · Base: `main` c9b42de5.
Todas las pruebas reales con HOME, almacén y claves aislados en directorios temporales; servidores solo en loopback.

## 1. Resultado global

- Suite de savia-vaults sobre c9b42de5: **721/721** (92 ficheros, 87,7 s).
- Pruebas reales repetidas hoy: escáner ClamAV gestionado, restauración desde el backup nocturno, límites y revocación en HTTP, revocación en MCP stdio y A2A sin token.
- **4 hallazgos nuevos**, 2 de seguridad. Ninguno lo detectaba la suite.

## 2. Hallazgos

| # | Gravedad | Hallazgo | Evidencia | Spec afectada | Arreglo propuesto |
|---|---|---|---|---|---|
| H1 | **Alta** | Con `scan: required`, un fichero de más de 2 GiB pasa como limpio sin analizarse. ClamAV no analiza más de 2 GiB − 1 por fichero y devuelve "OK" (código 0). Savia admite hasta 10 GiB. | Firma propia `.ndb` con marcador en el byte 0: 1 MB → FOUND (código 1); 2,3 GB → `stdin: OK` (código 0). Con `--alert-exceeds-max=yes` → `Heuristics.Limits.Exceeded.MaxFileSize`, código 2, que Savia ya trata como `SCAN_REQUIRED` (falla cerrado). | SE-421 (y SE-422, que es la vía natural para subir ficheros de más de 2 GiB) | Añadir `--alert-exceeds-max=yes` a `SIZE_ARGS` en `src/files/scan.ts`. Con `scan: required`, lo que no se puede analizar se rechaza con un motivo explícito (p. ej. `too-large-to-scan`). Con `scan: optional`, se guarda marcado como no analizado. Test con la firma `.ndb` y un stream de más de 2 GiB (unos 12 s). |
| H2 | **Alta** | **A2A** sin `SAVIA_VAULTS_TOKEN` sirve el contenido de cualquier cúpula, **N4 incluida**, y expone rutas absolutas. Envía `Access-Control-Allow-Origin: *`. No tiene usuarios, permisos por cúpula ni guarda de loopback: HTTP sí la tiene, A2A no. Con token, es un secreto compartido que se compara con `!==` (no en tiempo constante). | Loopback: una cúpula N4 con `clave-ultrasecreta-xyz` → `/search?q=clave` la devuelve y `/domes` da la ruta absoluta. Por código, `src/server/a2a.ts:133-152` y `src/cli/main.ts:94-96`: `--host` no se valida. Por el CORS `*`, cualquier web abierta en el navegador puede leer un A2A local. | SE-420 no se ve afectada (sus AC hablan de notas fuera de nivel); es deuda previa de A2A | Delta de identidad (SE-423): A2A pasa por el PDP común. Además, arreglo inmediato mínimo: A2A no arranca fuera de loopback sin token, sin `CORS *`, sin rutas absolutas y no sirve cúpulas N3/N4 sin usuario. |
| H3 | Media | **MCP no ve revocaciones** hasta reiniciar. `user revoke` y `user delete` no afectan a un proceso MCP ya abierto. HTTP sí las aplica en la siguiente petición (`reloadIfChanged`, solo en `http.ts`). | Cliente MCP real (stdio): antes de revocar, PERMITIDO; tras `revoke`, PERMITIDO; tras `delete`, PERMITIDO; en un proceso nuevo, `Invalid or expired token`. | SE-419/SE-422 (la revocación de SE-422 solo cubre HTTP) | SE-423: PDP común con recarga por cambio en todas las vías. Mínimo: llamar a `reloadIfChanged()` en `McpServer.authorize`. |
| H4 | Media | **`files setup` no instala los modelos del lector de PDF.** docling necesita modelos de HuggingFace y el worker corre con `HF_HUB_OFFLINE=1`. En un HOME limpio todos los PDF quedan `FAILED` (`LocalEntryNotFoundError`). SE-416 AC1 «real» pasó porque esta máquina ya tenía `~/.cache/huggingface` por otros usos. | Mismo PDF (`contrato.pdf`): HOME limpio → `FAILED`; tras enlazar la caché existente → `reprocess` → `READY`. Causa confirmada. | SE-416 | `files setup` descarga los modelos de docling (versión fijada y SHA-256) en `SAVIA_TOOLS_HOME`, y el worker usa `HF_HOME`/`artifacts_path` de ahí. `files status` avisa si faltan. |

Detalle menor: `savia-vaults.users.json` se crea en `0664` (hashes bcrypt legibles por el grupo; SE-423 §5). El `.sha256` del tar nocturno se crea con permisos `0664`, mientras el tar es `0600`. No filtra contenido.

Falsa alarma descartada: un EICAR añadido al final de 3 MB aleatorios no se detecta porque ClamAV ancla la firma EICAR al inicio del fichero. No es un fallo de Savia; para ficheros grandes hay que probar con una firma propia (H1).

## 3. Pruebas reales repetidas hoy

| Prueba | Resultado |
|---|---|
| ClamAV gestionado (1.5.4, firmas de hace 13 h), N2: EICAR, TXT, PDF | EICAR `QUARANTINED`; TXT `READY`; PDF `READY` solo con la caché de modelos (H4) |
| ClamAV gestionado, N3 cifrada: EICAR, TXT, binario de 3 MB por encima del tope de extracción (ruta stdin) | EICAR `QUARANTINED`; resto `READY`/`ARCHIVE_ONLY`; 0 ficheros con texto en claro en el almacén; `/dev/shm` sin restos |
| Backup nocturno real (`scripts/vaults-backup-cron.sh`, sin Nextcloud) → restaurar en un HOME vacío con `keys import` (fichero + frase + copia sellada) | `verify --deep` OK en N2 y N3; **5/5 originales idénticos byte a byte**, incluido uno subido a N3 después de exportar las claves |
| HTTP real, límites | 413 por encima de `SAVIA_FILES_MAX_BYTES`; 403 al subir un lector; 429 en la 3.ª subida activa con `MAX_ACTIVE_UPLOADS=2` |
| HTTP real, ACL y revocación en caliente | Lector 200 → `readers=[eva]` → 404 · eva 200 → `user revoke` → 403 · `user delete` → 401. Sin reiniciar. |
| MCP stdio real, revocación | No se aplica hasta reiniciar el proceso (H3) |
| A2A real sin token (loopback) | Sirve N4 (H2) |

No se volvió a medir hoy (la evidencia es de la entrega y la suite sigue en verde): rendimiento de RAG (SE-410/411), streaming de 2 GiB (SE-421) ni tus de 1 GiB (SE-422).

## 4. Matriz entrega · evidencia · pendiente · propuesta

| Spec | PR / commit | Evidencia de entrega | Pendiente o desviación | Propuesta de graduación |
|---|---|---|---|---|
| SE-410 RAG híbrido | #1188 | Banco de 36 consultas prerregistrado: híbrido MRR 0,566 (BM25 0,479); p95 caliente 179/302 ms | Elección de modelo con n=36 no significativa; BGE-M3 excluido (NaN) | **Graduar**; banco mayor como mejora, no bloqueo |
| SE-411 eficiencia RAG | #1189 (spec), #1190 | 6/6 AC con antes/después (`"*"` 2 032 → 154 ms; CLI 2,5 → 0,9 s) | — | **Graduar** |
| SE-412 higiene de búsqueda | #1191 | AC1, AC2, AC4–AC6 cumplidos | **AC3 no cumplido**: CLI ~500 ms frente a < 400 ms (límite del motor MiniSearch) | **Graduar con AC3 fallido aceptado**, o dejar abierta. Decide la operadora. |
| SE-413 Files MVP | #1193 | 9/9 AC; AC8 con escáner simulado | AC8 real repetido hoy con ClamAV gestionado: OK | **Graduar** |
| SE-414 endurecimiento | #1194 | 10 AC; bomba ZIP, 1 worker, symlinks | AC9 parcial (coste por documento con N grande) | **Graduar con AC9 parcial declarado** |
| SE-415 fidelidad de extracción | #1195 | 7/7 AC con fixtures reales | — | **Graduar** |
| SE-416 instalador | #1196 | ClamAV real y EICAR OK; idempotencia | **H4**: en una máquina limpia los PDF fallan; AC1 no era reproducible fuera de esta máquina | **No graduar** hasta arreglar H4 |
| SE-417 cifrado | #1197 | 10/10 AC; restauración repetida hoy: 5/5 idénticos | Desviaciones 1–4 documentadas (sin deduplicación en cifradas) | **Graduar** |
| SE-418 ledger | #1198 | 10/10 AC; `verify --deep` tras restaurar hoy: OK | Desviaciones 1–8 documentadas | **Graduar** |
| SE-419 ACL por documento | #1199 | 9/9 AC; HTTP en caliente hoy: 404 al lector excluido | H3 (MCP sin revocación) es de identidad, no de la ACL por documento | **Graduar**; H3 va a SE-423 |
| SE-420 nivel de nota | #1200 | 7/7 AC | H2 es previo a SE-420 y más amplio (A2A sin control) | **Graduar**; H2 aparte |
| SE-421 almacén en streaming | #1201 | 10/10 AC; 2 GiB con 141/160 MiB | **H1**: más de 2 GiB con `scan: required` pasa sin analizar | **No graduar** hasta arreglar H1 |
| SE-422 API HTTP/tus | #1202 (squash con título `se421` por error) | 9/9 AC; tus-js-client con reinicio; revocación HTTP en caliente repetida hoy | Hereda H1 (subidas de más de 2 GiB) | **Graduar junto con el arreglo de H1** |
| SE-402 ledger de ediciones | #1168, #1177 | La spec no tiene sección de resultados; evidencia de merge en #1177 | No revisada en este paquete (no es Vaults/Files) | Revisión aparte |
| SE-405 observabilidad | #1169, #1177 | Igual | No revisada en este paquete | Revisión aparte |

Graduar = `completion` con revisión humana → `IMPLEMENTED` en planning-state. Solo con la decisión de la operadora.

## 5. Arreglos propuestos (necesitan aprobación; SDD)

1. **H1 (SE-421 fix)**: `--alert-exceeds-max=yes`; rechazo explícito con `scan: required`; test con la firma `.ndb`. Unas 2 h de agente. Riesgo bajo.
2. **H2 inmediato (A2A)**: guarda de loopback, sin `CORS *`, sin rutas absolutas, sin N3/N4 sin usuario, comparación en tiempo constante. Unas 2 h. El modelo completo va en SE-423.
3. **H4 (SE-416 fix)**: modelos de docling fijados en `files setup` con verificación de SHA-256; test en HOME limpio. Unas 3 h; hay que confirmar el tamaño de la descarga (cientos de MB).
4. **H3**: `reloadIfChanged()` en MCP como parche de una línea, o esperar a SE-423.

## 6. Decisiones de la operadora (2026-09-30)

- Graduación: «9 limpias ahora» → SE-410, 411, 413, 414 (AC9 parcial declarado), 415, 417, 418, 419 y 420 pasan a IMPLEMENTED. SE-412 queda abierta; SE-416, 421 y 422 esperan a sus arreglos.
- Arreglos aprobados: H1, H2, H3 y H4 (SE-424), un PR por arreglo.
- SE-423 aprobada: tokens migrados caducan a los 365 días (D1); `SAVIA_VAULTS_TOKEN` obsoleto con aviso durante una versión (D2).

## 7. Delta de identidad mínima

Spec propuesta: `docs/specs/SE-423-vaults-minimal-identity.spec.md` (PROPOSED). Cubre Subject, credenciales con caducidad y revocación individual, PDP común para MCP, A2A, HTTP y CLI, y un corte de streams al revocar. Login con contraseña/MFA, SSO y AEK quedan fuera.
