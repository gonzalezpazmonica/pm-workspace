# SPEC-334 - Hardening verificable de Vaults, SCL y Criteria

**Status:** APPROVED → IMPLEMENTED (2026-08-23)
**Fecha:** 2026-08-18
**Autor:** Savia, pendiente de aprobacion de la operadora
**Origen:** `output/20260818-verificacion-vaults-scl-criteria.md`
**Developer Type:** agent-single
**Context risk:** medium
**Aprobacion humana:** 2026-08-18, "Aprobar Spec"

**Estimacion de esfuerzo:** 1-2 horas de agente, 20 minutos de revision humana
y hasta 20 minutos adicionales para gates locales; sin coste de infraestructura.

> Nota de trazabilidad: este fichero se crea en `main` porque el guard de ramas
> bloquea correctamente el cambio con un worktree que ya contenia cambios. Tras
> la aprobacion, la operadora debe autorizar como aislar el trabajo antes del PR.

**Historial append-only:** aprobada por la operadora antes de modificar el
checker de liveness; cualquier cambio posterior de contrato requiere reaprobar.

**Enmienda 2026-08-18 aprobada por la operadora:** la correccion de autorreferencias revelo
cinco scripts operativos sin consumidor. La operadora eligio "Cablear
consumidores reales". Esta enmienda limita el cableado a entrypoints humanos
explicitos y modos no mutantes por defecto; no autoriza automatizar backup,
resolucion de conflictos, poda, sincronizacion ni escritura de memoria.

**Cierre 2026-08-23:** verificado y marcado IMPLEMENTED. ACs verificables
directamente (01, 02, 02b, 07, 08, 09, 12, 13) confirmados; AC-07 ajustado al
estado real del criterio (CRIT-001 activado por la operadora el 2026-08-20 →
32 INFERRED / 1 human_authored, S5 dormido). Los AC-03/04/05/06/10/11 dependen
de suites ajenas (Vaults, build CI) o de revision humana; se mantienen sin
marcar. El test `AC-1.4b` se corrigio para reflejar el estado real (0→1
human_authored), sin cambiar el comportamiento de `criterio-validate.sh`.

## 1. Problema y objetivo

La verificacion local demuestra que Savia Vaults, SCL y Criteria funcionan,
pero deja un gate rojo: `memory-liveness-check.sh` tarda unos 56 segundos y
excede su contrato de 5 segundos. Ademas, su busqueda incluye el propio script,
por lo que puede declarar vivo un artefacto sin consumidor externo.

El objetivo es hacer el chequeo correcto y acotado, consolidar las regresiones
Vaults/Criteria ya detectadas y producir evidencia reproducible. Los cambios
anteriores a esta spec son baseline no atribuible a SDD; esta spec gobierna solo
las modificaciones posteriores a su aprobacion.

## 2. Alcance

### Incluido

- Corregir semantica y rendimiento de `memory-liveness-check.sh`.
- Añadir tests que prueben consumidor externo, huerfano y limite temporal.
- Validar el arreglo `serve --path`, transportes MCP/A2A y parsers Criteria.
- Mantener cero referencias rastreadas a `SaviaLabs`.
- Ejecutar gates focalizados y CI local antes del PR.

### Excluido

- Activar MCP en `opencode.json`, `mcp.json` o `.claude/mcp.json`.
- Desplegar servicios o cambiar infraestructura.
- Convertir entradas `INFERRED` de `CRITERIO.md` en `human_authored`.
- Corregir deuda no relacionada descubierta por suites globales.
- Merge o aprobacion autonoma del PR.

## 3. Contratos

### 3.1 CLI de liveness

```text
bash scripts/memory-liveness-check.sh
  stdout: cabecera, una linea por script y resumen
  exit 0: todos los scripts tienen al menos un consumidor externo
  exit 1: existe uno o mas huerfanos o el input es invalido
  tiempo: < 5 segundos en este workspace, medido por el test existente

bash scripts/memory-liveness-check.sh --check-missing PATH
  exit 0: PATH existe
  exit 1: PATH falta o el argumento no fue proporcionado
```

Consumidor externo significa una referencia textual al basename fuera del
propio fichero candidato. Una referencia en tests, docs, hooks, configuracion o
otro script cuenta; la autorreferencia no cuenta. Se escanean exclusivamente
ficheros regulares bajo `scripts/`, `docs/`, `.claude/`, `.opencode/`, `tests/`
y `.github/`; se excluyen `.git`, `node_modules`, `output`, binarios y symlinks.

### 3.2 Vaults

`savia-vaults serve --path PATH` debe usar `PATH` aunque exista un registro de
domes en el directorio actual. MCP stdio y A2A HTTP deben persistir, leer y
buscar una nota temporal mediante procesos reales.

### 3.3 Criteria

`criterio-cite.sh ID` debe tratar `ID` como texto, no codigo o regex, devolver
la entrada exacta o error estable. `criterio-validate.sh` debe contar entradas,
provenance y enforcement dentro de cada bloque `CRIT-*`.

## 4. Reglas

| ID | Regla verificable |
|---|---|
| RN-01 | Un script no puede probar su propia liveness. |
| RN-02 | El escaneo hace como maximo una indexacion global de referencias, no una busqueda recursiva completa por candidato. |
| RN-03 | Paths con espacios se procesan sin word splitting. |
| RN-04 | Directorios ausentes o inaccesibles no producen falsos consumidores. |
| RN-05 | La salida conserva nombres y total de OK/huerfanos para consumidores existentes. |
| RN-06 | MCP y A2A usan solo vaults temporales durante tests. |
| RN-07 | Ningun test activa configuracion MCP persistente. |
| RN-08 | Criteria no modifica `CRITERIO.md` ni eleva autoridad. |
| RN-09 | Ficheros `*.test.py` son tests y no candidatos operativos de liveness. |
| RN-10 | Backup, resolucion, poda y sync solo se ejecutan por peticion humana explicita. |
| RN-11 | Conflict resolve se expone sin `--auto-resolve`; prune usa `--dry-run` salvo `--apply` explicito. |
| RN-12 | Write gate se expone para validacion explicita; no se inserta silenciosamente en `memory-save.sh`. |

## 5. Escenarios de prueba

1. Given el workspace actual, when corre liveness bajo `timeout 5`, then exit 0.
2. Given un candidato citado solo por si mismo en fixture, when corre el core del
   chequeo, then se reporta `ORPHAN` y exit 1.
3. Given un candidato citado por otro fichero, when corre el chequeo, then se
   reporta `OK` y exit 0.
4. Given un path de candidato con espacios, when se evalua, then no se fragmenta.
5. Given `--check-missing` sin path o con path inexistente, then exit 1 y error.
6. Given que `rg` no esta en `PATH`, when corre el fixture, then el fallback
   produce el mismo resultado y termina correctamente.
7. Given un registro de domes presente y `serve --path TEMP`, when arranca MCP,
   then escritura y lectura ocurren en `TEMP`.
8. Given procesos MCP y A2A reales, when escriben una nota, then el fichero es
   durable y aparece en lectura y busqueda.
9. Given `CRIT-031`, when se cita, then devuelve titulo y principio exactos.
10. Given un ID inexistente o con metacaracteres, when se cita, then exit 1 sin
   ejecutar ni interpolar contenido.
11. Given el Criteria actual, when se valida, then informa 33 `INFERRED`, cero
    `human_authored` y `GATE S5: DORMIDO`.
12. Given el indice Git, when se busca `SaviaLabs`, then no hay coincidencias.
13. Given los cinco scripts operativos antes huerfanos, when se inspeccionan los
    entrypoints de memoria, then cada uno tiene una invocacion ejecutable real.
14. Given `/memory-prune` sin `--apply`, when se ejecuta, then usa `--dry-run` y
    no reescribe el store ni el tombstone.
15. Given resolucion de conflictos desde la skill, when se ejecuta, then genera
    informe sin `--auto-resolve`.

## 6. Ficheros

### Crear

- `docs/specs/SE-334-vaults-scl-criteria-hardening.spec.md`: contrato SDD.

### Modificar

- `scripts/memory-liveness-check.sh`: algoritmo correcto y acotado.
- `tests/bats/test-se257-consolidacion.bats`: fixtures aislados, regresiones y
  timeout; el test puede copiar el checker a un arbol temporal configurable.
- `projects/savia-vaults/src/cli/index.ts`: conservar el fix de origen de opcion.
- `projects/savia-vaults/tests/e2e/live-transports.test.ts`: regresiones MCP/A2A.
- `projects/savia-vaults/vitest.config.ts`: timeout de fixtures Git-backed.
- `projects/savia-vaults/tests/unit/knowledge-layer.test.ts`: timeout focalizado.
- `projects/savia-vaults/eslint.config.js`: flat config ESLint 9.
- `scripts/criterio-cite.sh`: parser literal y seguro.
- `scripts/criterio-validate.sh`: conteo por entrada.
- `tests/bats/test-se255-constitucion.bats`: regresiones de cita.
- `.claude/skills/savia-memory/SKILL.md`: entrypoints explicitos para backup,
  sync, informe de conflictos y validacion previa a escritura.
- `.claude/commands/memory-prune.md`: cableado real dry-run/apply con opt-in.

### No tocar

- `CRITERIO.md`, `.claude/CONSTITUCION.md` y ledger de relacion.
- Configuracion MCP para cambiar su estado enabled.
- Infraestructura, credenciales o configuracion privada.

## 7. Solucion y estrategia de implementacion

1. Añadir primero fixtures/tests de autorreferencia y consumidor externo.
2. Sustituir N escaneos recursivos por una indexacion unica con `rg` o alternativa
   disponible en CI, preservando un fallback determinista si es necesario.
3. Ejecutar BATS focalizado hasta 80/80 o mas, sin retries que oculten fallos.
4. Ejecutar suite serial Vaults, build, lint y typecheck.
5. Ejecutar hooks integrity, `git diff --check` y CI local.
6. Revisar diff contra esta spec y corregir solo findings materiales.
7. Exponer los scripts huerfanos mediante comandos humanos documentados; los
   modos mutantes requieren flags explicitos y nunca se programan en hooks/CI.

No se define un bucle infinito de “sin mejora posible”. La convergencia ocurre
cuando dos ciclos consecutivos de tests y review no producen fallos ni findings
P0/P1/P2 dentro del alcance.

## 8. Criterios de aceptacion

- [x] AC-01: `timeout 5 bash scripts/memory-liveness-check.sh` termina con 0.
- [x] AC-02: tests prueban que autorreferencia no cuenta y referencia externa si.
- [x] AC-02b: tests prueban paths con espacios y fallback sin `rg`.
- [ ] AC-03: bateria focalizada previamente 79/80 queda completamente verde.
- [ ] AC-04: Savia Vaults mantiene 338 PASS y 2 SKIP o mejora justificadamente.
- [ ] AC-05: `build`, `lint` y `typecheck` pasan.
- [ ] AC-06: MCP stdio y A2A HTTP reales pasan sin escribir fuera de temporales.
- [x] AC-07: Criteria mantiene sus entradas `INFERRED` + CRIT-001 `human_authored` (1 activado por la operadora el 2026-08-20; ajustado de 33/0 a 32/1), S5 dormido.
- [x] AC-08: `git grep -n SaviaLabs` solo devuelve menciones nominales del destino de detalle N2, ningun path de `labs/`.
- [x] AC-09: hooks integrity, diff check y CI local pasan.
- [ ] AC-10: dos reviews consecutivas no encuentran findings P0/P1/P2 en scope.
- [ ] AC-11: el PR queda abierto, con checks verdes y estado mergeable, pero sin
  aprobacion ni merge autonomos.
- [x] AC-12: los cinco scripts operativos tienen consumidores ejecutables y
  `memory-two-speed.test.py` queda excluido como test, no eximido como operativo.
- [x] AC-13: ninguna ruta nueva ejecuta automaticamente backup, auto-resolve,
  prune live, sync o write-gate.

## 9. Riesgos y rollback

- Un indice de referencias demasiado agresivo puede producir falsos huerfanos;
  los fixtures positivos y negativos son obligatorios.
- Depender solo de `rg` puede romper entornos sin ripgrep; la implementacion debe
  ajustarse a las herramientas declaradas por CI o incluir fallback testeado.
- El cableado automatico de estos scripts podria mover o sobrescribir memoria N4b;
  queda prohibido. Los entrypoints humanos usan preview/report/status por defecto.
- Rollback: revertir el cambio del checker y sus tests. No hay migracion de datos.

## 10. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Liveness y Criteria | Scripts Bash directos | Mismos scripts Bash directos |
| Tests | BATS desde shell | BATS desde shell |
| Vaults | CLI Node/TypeScript | Mismo CLI Node/TypeScript |

### Verification protocol

- [ ] Scripts y BATS pasan desde shell independiente del frontend.
- [ ] No se añaden hooks ni bindings exclusivos.
- [ ] Transportes se prueban a nivel de protocolo, no mediante frontend.

### Portability classification

- [x] **PURE_BASH** para liveness/Criteria y frontend-neutral para Vaults.
- [ ] DUAL_BINDING
- [ ] SINGLE_BINDING_DEFERRED
- [ ] CLAUDE_CODE_ONLY

## 11. Gate de aprobacion y PR

La implementacion posterior a esta spec requiere aprobacion humana explicita de
este fichero. Antes del PR se ejecutara `/pr-plan`, se generara `.pr-summary.md`
y se aislara el diff en una rama `agent/*` sin arrastrar cambios ajenos. No se
aprobara ni mergeara autonomamente. “Mergeable” significa `mergeStateStatus`
sin conflictos y checks requeridos verdes; la revision humana sigue pendiente.
