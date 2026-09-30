---
status: APPROVED
approved_at: 2026-09-30
approval: "Operadora 2026-09-30 en chat (AskUserQuestion): 'Aprobar e implementar'; antivirus 'clamscan por lote'; plataformas 'Linux ahora, resto después'"
priority: P1
developer_type: agent-single
created: 2026-09-30
author: Savia
phase: A
risk: L2
related_specs: [SE-413, SE-414, SE-415]
origin: petición de la operadora (2026-09-30) — toda dependencia de Savia Vaults necesita un instalador propio que Savia pueda ejecutar; un PM o analista no usa la consola
resource: https://github.com/gonzalezpazmonica/pm-workspace/tree/main/projects/savia-vaults/src/files
---

# SE-416 — Savia Files: instalador de dependencias sin consola ni administrador

## Problema

Savia Files depende de dos piezas externas y ninguna se puede instalar sin consola:

- **Extractor** (Python + Docling + openpyxl, ~1,5 GB): en esta máquina lo instaló
  la agente a mano con `uv venv` y `uv pip`. Un PM no sabe hacerlo, y sin él los
  PDF, DOCX, PPTX y XLSX quedan `ARCHIVE_ONLY`.
- **Antivirus** (ClamAV): hoy la documentación dice `sudo apt install clamav`. Pide
  administrador, que la agente no puede obtener (hook que bloquea sudo) y un PM
  no sabe usar. Tampoco hay forma de mantener las firmas al día.

Además, nada le dice a la persona en lenguaje llano qué falta y qué supone.

## Prueba de viabilidad (2026-09-30, Linux x86_64, glibc 2.39)

| Paso | Resultado |
|---|---|
| ClamAV en conda-forge | **No existe** (la vía micromamba se descarta) |
| Binario oficial Cisco Talos 1.5.4 (`.deb`, 106 MB) | SHA-256 igual al publicado; se desempaqueta sin root (`dpkg-deb -x` o `ar` + `tar`); 40 MB útiles |
| Rutas fijas | `RUNPATH=/usr/local/lib` y certificados en `/usr/local/etc/certs`; se resuelven con `LD_LIBRARY_PATH` y `CVD_CERTS_DIR` |
| `freshclam` a una carpeta de usuario | 108 MB de firmas en 11 s, con firma digital verificada |
| EICAR / PDF limpio | `Eicar-Test-Signature FOUND` (exit 1) / `OK` (exit 0) |
| Coste de `clamscan` | ~10 s y ~1 GB de RAM **por llamada** (carga 3,3 M de firmas) |

macOS (`.pkg` universal, `pkgutil --expand-full` sin root) y Windows (`.zip`
portátil, sin administrador) tienen binario oficial, pero **no se han probado**.

## Solución

### 1. Componentes gestionados, en el directorio del usuario

```
~/.savia-vaults/tools/
  python/                 intérprete gestionado por uv (si el sistema no tiene uno válido)
  uv/uv                   binario de uv (versión y SHA-256 fijados)
  files-venv/             venv del extractor (requirements.lock, con hashes)
  clamav/<versión>/       binarios ClamAV podados (bin, lib, certs)
  clamav/db/              firmas + freshclam.conf
  state.json              qué hay instalado, versiones, hashes, fecha de firmas
```

- Nunca pide administrador ni escribe fuera de `~/.savia-vaults/tools`.
- Cada descarga tiene la **versión, la URL y el SHA-256 fijados en el código** (por
  plataforma). Si el hash no coincide, se aborta y se borra lo descargado.
- La instalación es **atómica**: se prepara en un directorio temporal y se renombra
  al final. Si falla a medias, no queda nada roto y la instalación anterior sigue.
- Es idempotente: ejecutarla dos veces no descarga nada nuevo.
- Desinstalar borra el directorio del componente.

### 2. ClamAV sin administrador

- Descarga del binario oficial de Cisco Talos para la plataforma, verificación
  SHA-256, extracción sin instalar (Linux `.deb` con extractor `ar`/`tar` propio en
  TS; macOS `.pkg` con `pkgutil --expand-full`; Windows `.zip`) y poda a `clamscan`,
  `freshclam`, librerías y certificados.
- Todas las llamadas pasan `LD_LIBRARY_PATH` (o `DYLD_LIBRARY_PATH`),
  `CVD_CERTS_DIR` y `--database`.
- **Firmas al día sin intervención**: `freshclam` al instalar. Después, cada vez que
  se va a escanear, si las firmas tienen más de 24 h se lanza una actualización en
  segundo plano (como mucho una cada 4 h). El escaneo no espera.
- Si las firmas tienen más de 7 días: `files.scan: required` rechaza con un mensaje
  claro; `auto` escanea y lo avisa en `status`.
- `scan.ts` prefiere el ClamAV gestionado, después `SAVIA_FILES_CLAMSCAN`, después
  el del sistema.

### 3. Extractor sin consola

`uv` (binario único, versión y hash fijados) → intérprete gestionado si hace falta
→ venv → `uv pip sync workers/files/requirements.lock` con hashes. La primera
extracción descarga los modelos de Docling (~0,5 GB) y queda después sin red.
`SAVIA_FILES_PYTHON` sigue teniendo prioridad si está definido.

### 4. Superficies para que lo use Savia

- MCP `vault_files` con acciones nuevas:
  - `status`: qué hay, qué falta y qué supone, en frases para la persona. Por
    ejemplo: "Los PDF y Word se guardan pero no se leen: falta el lector de
    documentos (1,5 GB). ¿Lo instalo?".
  - `setup` con `components: ["extractor","antivirus"]`: instala y devuelve el
    progreso resumido.

  Ambas exigen que el servidor sea local (transporte stdio sin token) o un token
  con rol `admin`. Instalar software en la máquina no es un permiso de cúpula.
- CLI: `savia-vaults files setup [--extractor] [--antivirus] [--uninstall]` y
  `savia-vaults files status`, con salida en lenguaje llano.
- Skill `savia-vaults`: cuando una respuesta de `vault_files` indique
  `worker-missing` o que falta el escáner, Savia ofrece instalarlo, dice el tamaño
  y pide confirmación antes de ejecutar `setup`.

## Criterios de aceptación

- **AC1** En una máquina Linux x86_64 sin ClamAV ni venv, `files setup` instala
  ambos sin root. Después, un PDF queda `READY` y EICAR `QUARANTINED` (e2e real,
  en local).
- **AC2** Un SHA-256 distinto del fijado aborta sin dejar ficheros; la instalación
  previa sigue funcionando.
- **AC3** Un fallo a mitad (red cortada, simulado) no deja el componente a medias:
  `status` informa "no instalado" o la versión anterior.
- **AC4** Segunda ejecución: 0 bytes descargados.
- **AC5** Con firmas de más de 24 h se lanza una actualización en segundo plano y el
  escaneo no espera. Con más de 7 días y `required`, se rechaza con un mensaje que
  explica el motivo.
- **AC6** `status` devuelve, por componente, estado, versión, tamaño en disco,
  antigüedad de las firmas y una frase para la persona, sin rutas ni jerga.
- **AC7** `setup` por MCP con un token sin rol `admin` se rechaza.
- **AC8** Nada se escribe fuera de `~/.savia-vaults/tools`, que no puede estar
  dentro de un repo git.
- **AC9** La suite existente sigue en verde. Los tests de red usan un servidor
  local con artefactos falsos y hashes propios; la instalación real es un e2e
  manual que se documenta con los tiempos medidos.

## Entregables (rutas)

- Código: `projects/savia-vaults/src/files/setup.ts`, `projects/savia-vaults/src/files/deb.ts`,
  `projects/savia-vaults/src/files/scan.ts`, `projects/savia-vaults/src/files/extract.ts`,
  `projects/savia-vaults/src/files/service.ts`, `projects/savia-vaults/src/files/types.ts`,
  `projects/savia-vaults/src/cli/files.ts`, `projects/savia-vaults/src/server/mcp.ts`,
  `projects/savia-vaults/workers/files/requirements.in`, `projects/savia-vaults/workers/files/constraints.txt`,
  `projects/savia-vaults/workers/files/requirements.lock`.
- Tests: `projects/savia-vaults/tests/unit/files/setup.test.ts`, `projects/savia-vaults/tests/unit/files/deb.test.ts`,
  `projects/savia-vaults/tests/unit/files/scan.test.ts`, `projects/savia-vaults/tests/unit/files/service.test.ts`,
  `projects/savia-vaults/tests/unit/files/fake-artifacts.ts`, `projects/savia-vaults/tests/e2e/mcp-files.test.ts`,
  `projects/savia-vaults/tests/e2e/files.test.ts`.
- Documentación: `projects/savia-vaults/docs/files.md`, `projects/savia-vaults/README.md`,
  `projects/savia-vaults/CHANGELOG.md`, `.claude/skills/savia-vaults/SKILL.md`,
  `CHANGELOG.d/se416-savia-files-setup.md`, `docs/propuestas/planning-state.json`,
  `docs/propuestas/LOG.md`, `docs/propuestas/ROADMAP-CURRENT.md`.

## Decisiones de la operadora (2026-09-30)

- Antivirus: `clamscan` por lote, sin demonio residente.
- Plataformas: solo Linux por ahora. **Corrección**: la pregunta decía «x86_64 y
  arm64 con prueba real», pero esta máquina es x86_64 y arm64 no se puede probar.
  Se implementa solo x86_64; arm64, macOS y Windows lo indican en `status`.
- Añadido durante la implementación: `setup` por MCP corre en segundo plano (una
  instalación de 1,5 GB puede agotar el tiempo de una llamada) y el progreso se
  consulta con `status`.

## Resultados (2026-09-30)

Suite de savia-vaults: 585 tests en verde (561 con SE-415); `tsc` y `eslint` limpios.

| AC | Estado | Evidencia |
|---|---|---|
| AC1 | Cumple (real) | `files setup` en esta máquina, sin root, 31 s. Lote PDF + XLSX + EICAR con `scan: required` y solo lo gestionado: PDF y XLSX `READY`, EICAR `QUARANTINED` (`Eicar-Test-Signature`), 28 s |
| AC2 | Cumple | SHA-256 distinto → `INTEGRITY`, sin restos, la versión anterior sigue funcionando (test con servidor local) |
| AC3 | Cumple | Descarga cortada a mitad → `missing`, sin restos; `freshclam` fallido → no se da por instalado |
| AC4 | Cumple (real) | Segunda ejecución: 0 bytes, 0,5 s |
| AC5 | Cumple | > 24 h → `freshclam` en segundo plano (como mucho una vez cada 4 h), el análisis no espera; > 7 días + `required` → rechazo explicado |
| AC6 | Cumple | `status` por componente, con `summary` en frases sin rutas; también sin cúpula |
| AC7 | Cumple | `setup` por MCP con token de lector → error; `status` permitido (e2e) |
| AC8 | Cumple | El HOME de la persona queda intacto; `UNSAFE_HOME` dentro de git |
| AC9 | Cumple | Tests con artefactos falsos servidos en local; instalación real documentada arriba |

Hallazgos durante la implementación:

- ClamAV no existe en conda-forge; se usa el binario oficial desempaquetado.
- Los binarios de Talos traen `RUNPATH=/usr/local/lib` y certificados en
  `/usr/local/etc/certs`; la opción de configuración `CVDCertsDirectory` no basta
  (la librería no la usa), hace falta la variable `CVD_CERTS_DIR`.
- `freshclam` no toca las firmas si ya están al día: la antigüedad se mide con una
  marca `.last-update` que se escribe en cada comprobación correcta, no con la fecha
  de las firmas.
- `clamscan` cuesta ~10 s y ~1 GB por llamada; por eso el análisis es por lote.

## Esfuerzo

Agente 5 h · humano 45 min (+ prueba en macOS/Windows si se incluyen).

## Dependencias

SE-413/414/415. Descargas en tiempo de instalación: uv (GitHub astral-sh), ClamAV
(GitHub Cisco-Talos), firmas (database.clamav.net), paquetes PyPI del lock y
modelos de Docling (Hugging Face).

## Fuera de alcance

Demonio `clamd` residente (salvo que se decida lo contrario). Instalador gráfico.
Actualización automática de versión de ClamAV o del extractor (se hace con un
nuevo `setup` cuando cambia la versión fijada).

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP savia-vaults (`vault_files` status/setup) | `~/.claude.json` | `opencode.json` (mismo binario) |
| CLI `savia-vaults files setup/status` | bash | idéntico |

### Verification protocol

- [ ] `vault_files status` devuelve el mismo resumen en ambos frontends

### Portability classification

- [x] **PURE_NODE** (descarga binarios oficiales por plataforma; sin dependencias npm nuevas)
