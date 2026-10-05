---
status: PROPOSED
priority: P0
developer_type: agent-team
created: 2026-10-05
author: Savia
phase: A
risk: L3
related_specs: [SE-428, SE-429, SE-432]
origin: "Decisiones de la operadora del 2026-10-05 (AskUserQuestion): D-MED-1 sandbox propio de Space como frontera del modo mediado; D-MED-2 credenciales por proxy que inyecta; D-MED-3 desbloqueo (registro, ampliar el entorno, intención explícita, móvil); D-MED-4 MCP fuera del sandbox y el resto por lista derivada de la configuración de Savia, con acceso garantizado a cúpulas, repos, conexiones, MCP, A2A y APIs. Diseño completo en Savia Labs (privado)."
resource: https://code.claude.com/docs/en/sandboxing.md
---

# SE-434 — Savia Space: modo mediado con sandbox propio como frontera

## Problema

En modo mediado, Space decide cada permiso del motor (SE-428): lo deniega, lo aprueba solo o lo pregunta a la operadora. Hoy, para bash, lo decide analizando el texto de la orden con su deny-list. Ese modelo falla de dos maneras:

- **Deja a la operadora sin bash.** Con un plugin de sandbox de terceros activo, cada orden llega envuelta en su arranque. El proxy de red de ese arranque usa `socat` contra un socket Unix, y la deny-list lo juzga como una orden más y lo deniega. Resultado: se rechaza todo bash.
- **Space no es dueño de la frontera que juzga.** Reconocer por texto la estructura de un envoltorio ajeno es frágil (depende de la versión del plugin) y debilita la deny-list.

Claude Code lo resuelve de otra forma. El aislamiento lo impone el sistema operativo, no el análisis del texto: dentro de un sandbox verificado, bash se autoaprueba, y lo que necesita salir se pregunta.

## Objetivo

Que el modo mediado sea **seguro y funcional**:

- bash utilizable sin preguntar por cada orden;
- acceso a los recursos ya configurados de Savia: cúpulas, repositorios, remotos git, MCP, A2A y APIs;
- ninguna credencial al alcance del agente;
- ninguna denegación sin salida.

## Diseño

### 1. Sandbox propio de Space (D-MED-1)

En mediado, Space lanza el bash del agente dentro de **su propio** bubblewrap, con el binario de confianza. En ese modo no se cargan plugins de sandbox de terceros.

| Ámbito | Política |
|---|---|
| Sistema de ficheros | Worktree de la sesión en lectura y escritura. Lo declarado en el entorno (§2), en solo lectura. Nada más de `$HOME`, nunca ficheros de credenciales ni el estado privado de Space |
| Red | Namespace de red propio. Única salida: el proxy de Space (§3), por un socket montado por Space |
| Procesos e IPC | Namespace de PID propio. Sin acceso a los sockets de Space ni a `/proc` del host. La contraseña del motor no está presente |

- **Verificación (`isolation.state`).** Al arrancar y de forma periódica, una sonda desde dentro comprueba que lo prohibido falla y que lo permitido funciona. **Solo con `LIVE` se autoaprueba bash.** En cualquier otro estado, todo bash pregunta.
- **Prohibiciones duras.** Sobreviven al sandbox y las aplica la deny-list determinista: `sudo`, force push, borrados masivos fuera del worktree y lectura de credenciales. Nada las supera.
- **Orden de decisión**, como en `permissions` y el auto mode de Claude Code:
  1. prohibición dura → deny;
  2. `ask` explícito;
  3. `allow` explícito;
  4. dentro del sandbox `LIVE` → auto;
  5. si necesita salir del sandbox → preguntar.

### 2. Entorno derivado de la configuración de Savia (D-MED-4)

El entorno se **genera** desde la configuración real de Savia; no se escribe a mano. Se guarda con su hash, el doctor lo muestra y se regenera cuando cambia la configuración.

| Recurso | Acceso desde el modo mediado |
|---|---|
| Repositorio del workspace | Worktree en lectura y escritura; git local dentro del sandbox |
| Remotos git y GitHub | Por el proxy, solo hacia los hosts de los remotos y la API de GitHub, con credencial inyectada (§3) |
| Cúpulas (SaviaVaults) | Lectura dentro del sandbox. Escritura solo por la herramienta MCP, mediada |
| MCP | **Fuera del sandbox**: los lanza el motor y cada llamada pasa por la mediación de permisos |
| A2A y servicios locales | Solo los puertos de loopback **declarados** en la configuración de Savia, por el proxy |
| APIs | Por el proxy, con lista de dominios y credencial inyectada |
| Estado de Savia | No entra, salvo subrutas concretas declaradas y revisadas |

### 3. Proxy de red con inyección de credenciales (D-MED-2)

- El proceso del sandbox **no ve ningún secreto**: ni en el entorno ni en ficheros.
- El proxy de Space:
  - permite solo los destinos del entorno;
  - añade la credencial de cada destino;
  - termina TLS con una CA local en la que solo confía el sandbox.
- Una credencial nunca va a un destino que no le corresponde. Un destino no permitido se deniega con `[Red no permitida]` y queda registrado.
- Los remotos ssh se reescriben a HTTPS por el proxy; ssh no entra en el sandbox.

### 4. Desbloqueo (D-MED-3)

- **Registro de denegaciones.** Un panel muestra la orden, la sesión y el motivo entre corchetes: `[Credenciales]`, `[Red no permitida]`, `[Fuera del worktree]` o `[Prohibición dura]`. Se alimenta del registro de decisiones existente.
- **Ampliar el entorno desde la UI.** Con un toque desde una denegación se añade el dominio o la ruta al entorno del workspace. El alcance es explícito y queda registrado; nunca hay «siempre» global.
- **Intención explícita.** Una prohibición blanda (por ejemplo, `git push` a una rama propia) se supera si la operadora lo escribe expresamente en el chat de esa sesión, y la cita queda registrada.
  - Solo cuentan los mensajes tecleados en la UI por la sesión emparejada, nunca las salidas de herramientas.
  - Las prohibiciones duras no se superan.
- **Móvil.** Lo que se pregunta llega como aviso al cliente móvil (SE-430), con Permitir una vez y Rechazar.

## Slices

Cada slice es un PR Draft independiente, con TDD y con verificación contra el motor real.

| Slice | Contenido | Aceptación |
|---|---|---|
| S1 | Sandbox propio de bash en mediado, sonda de aislamiento y orden de decisión | AC1–AC4 |
| S2 | Entorno derivado y `doctor --environment` | AC5–AC6 |
| S3 | Proxy con lista de destinos e inyección de credenciales | AC7–AC9 |
| S4 | Desbloqueo: registro, ampliar el entorno, intención explícita y móvil | AC10–AC13 |

## Criterios de aceptación

- **AC1:** en mediado, con el sandbox `LIVE`, una orden del workspace (`python3 --version`, `cargo test`) se ejecuta sin preguntar.
- **AC2:** con el sandbox en otro estado distinto de `LIVE` (sonda fallida, binario no fiable), todo bash pregunta. Se prueba falseando la sonda.
- **AC3:** las prohibiciones duras se deniegan siempre, aunque el sandbox ya las impidiera. Se prueba con el corpus del red team de la deny-list, sin fugas.
- **AC4:** la sonda verifica, desde dentro del sandbox, que fallan:
  - la lectura de `~/.ssh` y de los ficheros de credenciales;
  - la escritura fuera del worktree;
  - la red directa;
  - el acceso a los sockets de Space;
  - la lectura de la contraseña del motor.
- **AC5:** `doctor --environment` prueba cada recurso desde dentro del sandbox, y todos pasan:
  - `git fetch` del remoto;
  - `gh api user`;
  - una búsqueda en una cúpula;
  - una llamada MCP;
  - un ping A2A a un puerto declarado.
- **AC6:** un recurso no declarado falla con su motivo: un puerto de loopback sin declarar, un dominio ajeno o una ruta de `$HOME`.
- **AC7:** volcar el entorno y el sistema de ficheros desde dentro del sandbox no revela ninguna credencial. Se prueba buscando los tokens reales sin imprimirlos.
- **AC8:** el proxy inyecta cada credencial solo hacia su destino. Una petición hacia un destino permitido pero ajeno a esa credencial sale sin ella.
- **AC9:** un dominio no permitido se deniega con `[Red no permitida]` y queda registrado.
- **AC10:** cada denegación aparece en el panel con su motivo.
- **AC11:** ampliar el entorno desde una denegación permite la siguiente orden equivalente, con alcance de workspace y registro.
- **AC12:** la intención explícita solo vale si la escribe la operadora en la UI. El mismo texto en la salida de una herramienta no desbloquea nada.
- **AC13:** una pregunta llega al móvil y se resuelve desde allí.
- **AC14:** la rúbrica de experiencia de SE-432 no empeora con el modo mediado activo frente al modo interactivo.

## Fuera de alcance

- El modo interactivo: sigue con la configuración del motor de la operadora.
- Un juez con modelo para decidir permisos, descartado en D-MED-1.
- Windows: el diseño de la DACL va aparte.

## Riesgos

- **CA local:** es una superficie nueva. Solo confía en ella el sandbox, nunca el host, y hay que diseñar su rotación.
- **Recursos de Savia que no hablan HTTP** (sockets Unix de daemons): se inventarían y se decide uno a uno.
- **Rendimiento:** un bwrap por orden frente a un sandbox persistente por sesión. Se mide en S1.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Mediación de permisos de Space | No aplica (Space orquesta el motor por API) | Space configura `permission` del motor y responde a `permission.asked` |
| Sandbox de bash | No aplica (Claude Code tiene su propio `/sandbox`) | Space envuelve bash en su bwrap; en mediado no se carga el plugin de sandbox de terceros |
| Guards de Savia (savia-gates) | Hooks `PreToolUse` | Plugin savia-gates fijado, como hoy |

### Verification protocol

- [ ] Funciona en runtime OpenCode (motor real, modo mediado)
- [ ] Tests cubren ambos paths (dentro del sandbox LIVE y fuera de LIVE)
- [ ] Si añade hooks: registrados en plugin `savia-gates`

### Portability classification

- [x] **SINGLE_BINDING_DEFERRED**: Space es el cliente de orquestación sobre OpenCode (SE-428). Claude Code ya tiene su sandbox y su auto mode nativos, de los que este diseño toma el modelo. No hay port pendiente: cada motor usa su mecanismo nativo.
