---
status: IMPLEMENTING
approved_at: 2026-10-02
approval: "Operadora 2026-10-02 en chat: diseño aceptado («Aceptar ya»); sprint nocturno «Continúa de forma autónoma con Savia Space y permisos de merge hasta que tengamos el primer mvp funcional»; SE-396 sale del WIP; código en projects/savia-space con datos sintéticos N1"
priority: P1
developer_type: agent-single
created: 2026-10-02
author: Savia
phase: A
risk: L2
related_specs: [SE-410, SE-413, SE-423, SE-396]
origin: "Diseño de producto aceptado por la operadora el 2026-10-02 (el diseño completo es privado; esta spec recoge el contrato público de la versión 0.1)"
resource: https://github.com/gonzalezpazmonica/savia/tree/main/projects/savia-space
---

# SE-427 — Savia Space 0.1: espacio de trabajo local de solo lectura sobre las cúpulas

## Problema

Para trabajar con el conocimiento de las cúpulas (SaviaVaults) hoy hace falta un frontend de
agentes (Claude Code, OpenCode). No hay una superficie para una persona que quiera:

- buscar notas en sus cúpulas con su propio acceso,
- elegir qué fuentes entran al contexto,
- ver exactamente qué se enviará al modelo antes de enviarlo,
- y recibir una respuesta cuyas citas se comprueban contra las fuentes, no se dan por buenas.

## Objetivo

Un servidor local y un cliente web que hagan eso con un modelo local (Ollama), sin efectos
fuera de la máquina y sin conceder autoridad nueva a ningún agente.

## Alcance 0.1

- **Solo lectura** (addendum READ_ONLY de ADR-002): lee notas con la credencial de lectura de
  la persona, escribe solo en su estado privado local. Sin efectos, sin herramientas, sin red
  salvo loopback hacia Ollama y el proceso de Vaults.
- **Local**: escucha en `127.0.0.1`; allowlist de `Host`/`Origin`; las mutaciones exigen
  `X-Space-Request: 1`; cookie `HttpOnly; SameSite=Strict`; emparejado por socket unix `0600`
  con código de un solo uso.
- **Aprobación de bytes exactos**: `prepare` devuelve el cuerpo exacto (JCS, RFC 8785) y su
  `payloadHash`; el cliente verifica el hash en el navegador antes de habilitar «Enviar»; el
  servidor envía exactamente esos bytes.
- **Ejecución**: máquina de estados QUEUED → RESOLVING → RUNNING → VALIDATING → terminal;
  un run activo por sesión (índice único parcial); `DISPATCH_INTENT` antes del envío; la
  recuperación nunca reenvía; cancelación con valla.
- **Validación determinista**: cada cita debe aparecer literalmente (EXACT o WHITESPACE) en su
  fuente; PASS exige todas las fuentes citadas y cada afirmación `quoted`/`inferred` enlazada a
  una cita verificada. Sin relajación.
- **Tiempo real**: SSE con backlog y dedupe por secuencia, `Last-Event-ID`; el stream revalida
  la cookie cada 5 s.
- **Retención**: 30 días configurables (7–365) sin turnos; nunca se purga una sesión con run
  activo.
- **Datos públicos**: el repo solo contiene corpus sintético N1 (`fixtures/n1`).

## Fuera de alcance 0.1

Efectos y herramientas, ficheros de Savia Files (0.3), copia de seguridad y restauración,
`doctor` completo, emparejado en Windows, SSO.

## Criterios de aceptación

- **AC1**: `cargo test --workspace` en verde; `clippy -D warnings` y `fmt --check` limpios.
- **AC2**: `npm test` y `npm run build` del cliente en verde (TypeScript estricto).
- **AC3**: e2e con la UI real (Chrome headless, `apps/web/e2e/ui.e2e.mjs`) completa
  emparejado → sesión → búsqueda/captura/selección → prepare → hash verificado en navegador →
  envío → respuesta con citas verificadas → exportación, con proveedor simulado y con un modelo
  local real.
- **AC4**: un historial con mensajes de otra sesión se rechaza (test de regresión).
- **AC5**: una sesión web revocada cierra los streams SSE abiertos (test).
- **AC6**: la purga de retención respeta runs activos y borra en cascada (test).
- **AC7**: ningún fichero de `projects/savia-space` contiene datos N2+ ni referencias privadas
  (auditoría de confidencialidad del PR).

## OpenCode Implementation Plan

### Bindings touched

Ninguno: producto independiente (Rust + Vue) en `projects/savia-space`; no añade hooks,
agentes ni skills al workspace.

### Verification protocol

- [x] Funciona sin frontend de agentes (servidor y navegador).
- [x] Tests Rust y Vitest independientes del frontend.
- [ ] Si en el futuro lee `.opencode/agents`, test de carga con OpenCode.

### Portability classification

- [x] **PURE_BASH** (equivalente: binario y cliente sin bindings de frontend)

## Resultados

- 2026-10-02: MVP funcional en local. 128 tests Rust + 11 Vitest. e2e UI con gemma3:4b:
  comparar (3 fuentes) 3/3 PASS, resumir PASS, borrador de spec PASS. Dos fallos encontrados y
  corregidos con test: historial entre sesiones aceptado; contrato de salida que dejaba una
  fuente sin citar (corregido en el contrato, no en la validación).
