---
status: PROPOSED
priority: P1
developer_type: agent-single
created: 2026-10-02
author: Savia
phase: A
risk: L3
related_specs: [SE-427, SE-429, SE-430, SE-431, SE-401, SE-396, SE-304]
origin: "Mandato de la operadora: Savia Space como cliente sustituto de OpenCode, compatible con él, con la arquitectura de Savia y con sus flujos y hooks. Decisiones 2026-10-02 (AskUserQuestion): modelo híbrido con OpenCode como motor; sustituto primero; hooks bash registrados; sesión interactiva en el checkout"
resource: https://opencode.ai/docs/server/
---

# SE-428 — Savia Space como sustituto de OpenCode, con OpenCode como motor

## Problema

Savia trabaja hoy a través de frontends de agentes, sobre todo OpenCode. Savia Space 0.1
(SE-427) es solo un espacio de lectura con evidencia: no lleva sesiones de agente, ni
herramientas, ni comandos, ni hooks. El encargo original de Space era otro: un cliente que
**sustituya a OpenCode y sea compatible con él**, con la arquitectura, los flujos y los hooks de
Savia.

## Objetivo

Que la operadora pueda hacer una jornada normal de Savia en Space sin abrir la TUI de OpenCode.

- **Mismo motor**: Space conduce el servidor de OpenCode con el mismo `opencode.json`, los mismos
  plugins y guards de Savia, y los mismos agentes, skills, comandos y MCP.
- **Sesiones compatibles en los dos sentidos**: también se abren con `opencode attach`.
- **Más de lo que da OpenCode**:
  - evidencia de bytes exactos (SE-427);
  - recibos, plano e inspector;
  - interop con terceros (SE-429) y móvil (SE-430);
  - Savia Soul (SE-431).

## Dos perfiles de ejecución

| | Interactivo (paridad) | Mediado |
|---|---|---|
| Cuándo | la operadora conduce la sesión | Soul, terceros, schedules y sprints autónomos |
| Permisos | los de `opencode.json`, sin cambios; las preguntas del motor van a la UI de Space | `opencode.json` endurecido por Space: toda acción con efecto pregunta; envolvente de tarea y lista bloqueada |
| Directorio | el checkout del proyecto, como hoy en OpenCode | worktree propio en una rama `agent/*` |
| Evidencia | historial y diff de la sesión | recibo firmado de la tarea |

Space nunca afloja `opencode.json`; solo puede endurecerlo. Las reglas de seguridad autónoma
(ramas `agent/*`, PR solo en Draft, nunca merge sin grant) aplican igual que hoy.

## Diseño

1. **Proceso del motor.**
   - Space arranca `opencode serve` en loopback, con puerto aleatorio y una contraseña aleatoria
     por arranque. El servidor de OpenCode no tiene autenticación sin ella (verificado en
     1.18.32).
   - Fija el hash de la OpenAPI del motor y no lo usa si no coincide.
   - Carga los plugins del workspace (sin `--pure`). Si falta el plugin de guards de Savia, el
     motor queda en modo degradado y no admite sesiones con escritura.
   - Si el motor cae, la ejecución queda interrumpida y nunca se reenvía un prompt
     automáticamente.
2. **Paridad con OpenCode.**
   - **P0**: sesiones (crear, listar, renombrar, borrar, fork), prompt con streaming y abort,
     permisos y preguntas, cambio de agente y de modelo, paleta de comandos, catálogo de agentes
     y skills, diff y revert, `opencode attach`.
   - **P1**: terminal, explorador de ficheros, todo y subagentes, MCP, compactar.
   - Compartir sesiones públicamente queda desactivado.
3. **Hooks de Savia.**
   - Dentro del motor, los guards del plugin de Savia siguen actuando como hoy.
   - Para los eventos que ocurren en Space (prompts desde la web, el móvil, la mensajería o A2A;
     exportar; crear ramas o PR Draft; compactar; fin de turno), Space ejecuta **los mismos hooks
     registrados en `.claude/settings.json`**, con el contrato de Claude Code y sin reimplementarlos.
   - Sin doble disparo: lo que ya cubre el plugin no se repite.
   - Nunca se ejecutan hooks declarados en assets importados.
4. **Instrucciones y modelos.**
   - Las sesiones de agente cargan las instrucciones de `opencode.json`, como hoy.
   - Los modelos se resuelven por tier, con Space como un frontend más del esquema de tiers.
     Ningún modelo se fija en el código.
5. **Mediación** (solo en el perfil mediado). Space decide cada petición de permiso del motor:
   - **denegar**: lista bloqueada;
   - **automático**: dentro de la envolvente;
   - **persona**: en el resto, desde la web, el móvil o A2A.
   Una automatización nunca responde "siempre".
6. **Evidencia** (perfil mediado). Recibo firmado con:
   - envolvente y aprobación;
   - versiones y hashes del motor, plugins y configuración;
   - commits base y final;
   - cada llamada a herramienta con su decisión;
   - hash del diff, checks y estado final.
7. **Flujos de Savia.** Clock-in/clock-out, `pr-plan`, validación local de CI, roadmap, memoria,
   overnight-sprint y code-improvement-loop se ofrecen como acciones ejecutadas por el motor. Space
   no los reescribe.

## Fuera de alcance

- Efectos externos generales (API de terceros, despliegues): siguen esperando a un contrato de
  admisión aprobado (AEK, ADR-002 fase F).
- Merge de PRs por agentes.
- Sustituir el motor de OpenCode en esta spec.

## Entregas

- **0.2 (sustituto mínimo)**: motor, paridad P0 en modo interactivo, hooks de Savia en eventos
  de Space y `opencode attach`.
- **0.3**: paridad P1, modo mediado con recibos y flujos de Savia como acciones.
- **0.4**: interop con terceros (SE-429) y móvil (SE-430).
- **0.5**: Savia Soul (SE-431).

## Criterios de aceptación

- **AC1**: un motor con OpenAPI distinta de la fijada no se usa; uno sin el plugin de guards no
  admite escritura.
- **AC2**: el puerto del motor rechaza peticiones sin contraseña.
- **AC3**: en una sesión interactiva, un `git push --force` del agente lo bloquea el guard de Savia,
  igual que en OpenCode.
- **AC4**: un prompt enviado desde Space ejecuta los hooks `UserPromptSubmit` registrados; si uno
  bloquea, el prompt no llega al motor.
- **AC5**: un comando de la paleta produce la misma salida que en OpenCode, con el mismo modelo y
  la misma sesión.
- **AC6**: una sesión creada en Space se abre con `opencode attach` con el mismo historial, y un
  permiso pendiente aparece en ambos.
- **AC7**: en modo mediado, un permiso de edición que `opencode.json` permite se convierte en
  pregunta, sin modificar el fichero.
- **AC8**: un hook declarado en un asset importado no se ejecuta.
- **AC9**: en modo mediado, el recibo verifica con la clave pública de la instancia y su hash de
  diff coincide con el worktree.
- **AC10**: cinco jornadas de trabajo real de la operadora solo con Space, sin abrir la TUI de
  OpenCode para nada de P0. Cada apertura necesaria se registra con su causa.

## Decisiones pendientes

- **D1**: addendum a ADR-002 — Space como frontend de Savia no amplía la autoridad: herramientas
  locales con los hooks de Savia; efectos externos con admisión externa.
- **D2**: un motor por proyecto (propuesto) o uno por usuaria.
- **D3**: sandbox obligatorio para ejecuciones mediadas con shell (propuesto).

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode |
|---|---|---|
| Motor de agentes | no aplica en esta spec | `opencode serve` como proceso hijo; API fijada por hash de OpenAPI; `opencode attach` compatible |
| Hooks de Savia | los scripts de `.claude/settings.json` se ejecutan desde el bus de Space con el contrato de Claude Code | el plugin de guards de Savia sigue cargado en el motor |
| Agentes, skills y comandos | sin cambios | se leen del catálogo del motor (`.opencode/agents`, skills, commands) |

### Verification protocol

- [ ] Tests de contrato del adaptador contra la versión de OpenCode fijada.
- [ ] Canarios por hook: cada evento se dispara una sola vez (motor o bus).
- [ ] Escenarios AC1–AC9 en CI con un motor local de prueba; AC10 con la operadora.

### Portability classification

- [x] **DUAL_BINDING**: los hooks de Savia funcionan con el contrato de Claude Code (bus de Space) y
  con el plugin de OpenCode (motor) desde el primer slice. El motor es OpenCode; los adaptadores
  de Codex y Claude Agent SDK quedan para después de la ablación (ADR-002 fase D).
