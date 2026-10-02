---
status: PROPOSED
priority: P1
developer_type: agent-single
created: 2026-10-02
author: Savia
phase: A
risk: L3
related_specs: [SE-427, SE-429, SE-430, SE-401, SE-396]
origin: "Decisión de la operadora 2026-10-02 (AskUserQuestion): modelo híbrido — Savia Space es el cliente y orquestador completo; OpenCode es el motor de agentes vía su servidor HTTP; sustitución del motor por fases"
resource: https://opencode.ai/docs/server/
---

# SE-428 — Savia Space como orquestador: OpenCode como motor de agentes

## Problema

Savia trabaja hoy a través de frontends de agentes (OpenCode, Claude Code). Cada uno trae su
propia interfaz, su propio modelo de permisos y su propio registro de lo que pasó:

- No hay una superficie única donde una persona lance, siga y apruebe el trabajo de los agentes.
- Desde el móvil o desde otros agentes y servicios no hay forma de hacerlo.
- Cuando un agente toca ficheros o ejecuta comandos, la evidencia queda repartida entre logs del
  frontend, el historial de git y la memoria de la conversación.

Savia Space 0.1 (SE-427) resolvió esto para trabajo de **lectura con evidencia**. No conduce
agentes con herramientas.

## Objetivo

Space pasa a ser el cliente y orquestador completo de Savia. OpenCode es su **motor**, no su
interfaz:

- Space lanza y conduce el bucle de agentes por el servidor HTTP de OpenCode.
- Space media cada permiso con efecto.
- Space deja un recibo verificable de cada tarea.

El motor se puede sustituir más adelante (Codex app-server, Claude Agent SDK o un motor propio),
pero solo si una ablación demuestra que aporta.

## Dos tipos de ejecución, con garantías distintas

| | Ejecución de evidencia (0.1) | Ejecución de agente (nueva) |
|---|---|---|
| Quién llama al modelo | Space | el motor |
| Qué aprueba la persona | los bytes exactos enviados | una envolvente de tarea y cada permiso con efecto |
| Qué garantiza Space | lo enviado es lo aprobado | lo observado y mediado (mensajes, herramientas, decisiones, diff); no los bytes que el motor envía |

La interfaz y los recibos nunca presentan una ejecución de agente con la garantía de una de
evidencia.

## Diseño

1. **Proceso del motor.**
   - Space arranca `opencode serve` como proceso hijo: loopback, puerto aleatorio y una
     contraseña aleatoria por arranque (`OPENCODE_SERVER_PASSWORD`). El servidor de OpenCode no
     tiene autenticación sin ella (verificado con 1.18.32).
   - Space compara el hash de la OpenAPI del motor con el fijado; si no coincide, no lo usa.
   - Los plugins de Savia siguen cargados dentro del motor (sin `--pure`). Es defensa en
     profundidad.
   - Si el motor cae: la ejecución queda `INTERRUPTED` y nunca se reenvía un prompt
     automáticamente.
2. **Espacio de trabajo.**
   - Cada tarea que escribe trabaja en un worktree propio en una rama `agent/*`.
   - Se heredan las reglas de seguridad autónoma: PR solo en Draft, y nunca merge, push forzado
     ni aprobación por agentes.
3. **Mediación de permisos.**
   - El motor se configura con toda acción con efecto en `ask`. Space decide cada petición:
     - **denegar**: lista bloqueada (sudo, borrado recursivo, push forzado, merge, escritura
       fuera del worktree, credenciales, red no permitida);
     - **automático**: dentro de la envolvente aprobada;
     - **persona**: en el resto. Se resuelve en la interfaz web, en el móvil (SE-430) o como
       `input-required` en A2A (SE-429).
   - Una automatización nunca responde "siempre".
   - Las preguntas del motor van siempre a una persona.
   - Las vías de bypass se declaran (plugins y MCP del motor, efectos indirectos de comandos
     permitidos, terminal interactiva) y se mitigan: componentes fijados por hash, terminal
     desactivada en tareas automáticas y sandbox para riesgo alto.
4. **Envolvente de tarea.**
   - Contiene: proyecto, repositorio y rama base, agente, modelo, prompt, herramientas
     permitidas y automáticas, lista bloqueada, presupuesto (pasos, tokens, tiempo), egreso,
     nivel de confidencialidad y caducidad.
   - Su hash se aprueba con los mismos modos que SE-429 (persona, delegación acotada, lease
     externo).
   - Si se excede el presupuesto, la tarea se aborta y el trabajo queda en el worktree para
     revisión.
5. **Evidencia.** Recibo firmado por la instancia con:
   - envolvente y aprobación;
   - versión y hashes del motor, plugins y configuración;
   - commits base y final;
   - cada llamada a herramienta con su decisión, quién la tomó y los hashes de argumentos y
     resultado;
   - hash del diff, checks y estado final.
6. **Interfaz común.** Las tareas de agente se exponen por las mismas superficies que el resto
   de Space: REST, MCP, A2A y móvil.

## Fuera de alcance

- Efectos externos generales: API de terceros, despliegues, escritura en sistemas ajenos. Siguen
  bloqueados hasta que exista un contrato de admisión aprobado (AEK, ADR-002 fase F).
- Merge de PRs por agentes.
- Sustituir el motor en esta spec.

## Entregas

- **0.2**: adaptador del motor y tareas de agente de solo lectura (explicar, planificar, revisar).
- **0.3**: edición en worktree con mediación, diff, revert, checks y recibos.
- **0.4**: comandos de shell con allowlist; aprobaciones desde el móvil; push de ramas `agent/*`
  y PR Draft con aprobación humana.

## Criterios de aceptación

- **AC1**: un motor con OpenAPI distinta de la fijada no se usa.
- **AC2**: el puerto del motor rechaza peticiones sin contraseña.
- **AC3**: un `push --force` pedido por el agente se deniega automáticamente y queda registrado.
- **AC4**: una edición dentro de la envolvente se autoriza una vez y queda registrada.
- **AC5**: una acción fuera de la envolvente espera a una persona.
- **AC6**: si el motor muere a mitad de tarea, la ejecución queda interrumpida, sin reenvío, y el
  diff queda visible.
- **AC7**: al exceder el presupuesto se aborta y el worktree se conserva.
- **AC8**: ningún camino de automatización responde "siempre" a un permiso.
- **AC9**: el recibo verifica con la clave pública de la instancia y su hash de diff coincide con
  el worktree.

## Decisiones pendientes

- **D1**: addendum a ADR-002. Space como frontend de Savia hereda las reglas del harness y no
  amplía autoridad: herramientas locales en worktree con mediación y efectos externos con
  admisión externa. Se necesita antes de ejecuciones con escritura.
- **D2**: un motor por proyecto (propuesto) o uno por usuaria.
- **D3**: sandbox obligatorio para ejecuciones con shell desde 0.4 (propuesto).
- **D4**: proveedores en la nube para el motor desde 0.2 o solo locales (propuesto: locales).

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode |
|---|---|---|
| Motor de agentes | no aplica (Space no conduce Claude Code en esta spec) | `opencode serve` como proceso hijo; API HTTP fijada por hash de OpenAPI |
| Plugins y hooks de Savia | sin cambios | se cargan dentro del motor; conjunto fijado por hash |
| Agentes y skills | sin cambios | `.opencode/agents` y skills se leen del catálogo del motor |

### Verification protocol

- [ ] Tests de contrato del adaptador contra la versión de OpenCode fijada.
- [ ] Escenarios AC1–AC9 en CI con un motor local de prueba.
- [ ] Sin hooks nuevos en el workspace.

### Portability classification

- [x] **SINGLE_BINDING_DEFERRED**: el primer motor es OpenCode. Los adaptadores de Codex
  app-server y Claude Agent SDK quedan tras la ablación (ADR-002 fase D), con el trait de motor
  como contrato común.
