---
status: PROPOSED
priority: P2
developer_type: agent-single
created: 2026-10-02
author: Savia
phase: A
risk: L4
related_specs: [SE-427, SE-428, SE-429, SE-430, SE-406, SE-409, SPEC-186]
origin: "Mandato de la operadora 2026-10-02: Savia Space debe contar con un flujo continuo configurable y activable bajo demanda, Savia Soul, que emule a bots autónomos (OpenClaw, Hermes, OpenAI Five, Meta Muse, Grok Bot), con el que otros bots se comuniquen por A2A y la operadora por chat o mensajería"
resource: https://github.com/nousresearch/hermes-agent
---

# SE-431 — Savia Soul: la Savia proactiva dentro de Savia Space

## Problema

Savia solo trabaja cuando alguien abre una sesión o lanza una automatización programada. Los
bots autónomos actuales trabajan de otra forma:

- **OpenClaw**: latido periódico; identidad en ficheros.
- **Hermes**: aprende skills y memoria; pasarela de mensajería.
- **Meta Muse**: tareas largas en un entorno aislado, con un mediador que el agente no puede
  saltarse.
- **Grok Bot**: agentes persistentes que solo vuelven a la persona para aprobar, y que se
  coordinan entre ellos.
- **OpenAI Five**: ciclo continuo a ritmo fijo y aprendizaje fuera de producción.

Savia no tiene ese modo, ni una forma de que otros bots hablen con ella.

## Objetivo

**Savia Soul** es un bucle continuo dentro de Savia Space, configurable y activable bajo demanda:
**percibe**, **delibera**, **actúa**, **reflexiona** y **duerme**.

- Vigila, avisa, pregunta, propone y ejecuta trabajo acotado.
- Habla con la operadora por chat (web y móvil) y por mensajería (Savia Relay, SE-406).
- Habla con otros bots por A2A.
- Su voz es la de Savia.

**Regla madre: Soul solo actúa a través de las primitivas de Space**:

- ejecuciones de evidencia (SE-427);
- tareas de agente con envolvente y mediación de permisos (SE-428);
- mensajes y A2A (SE-429).

No tiene ningún otro camino al mundo. La mediación de Space es su "Sentinel": no puede
saltársela ni reconfigurarla.

## Diseño

1. **Configuración.**
   - Modos: apagado, bajo demanda, programado o continuo.
   - Latido (mínimo 5 minutos), horas activas y de silencio, y eventos que despiertan (CI, PRs,
     ejecuciones, aprobaciones, cúpulas, mensajes).
   - Órdenes permanentes: cada una con objetivo, disparador, envolvente y autonomía (observar,
     proponer o actuar).
   - Canales, bots permitidos y presupuestos (tokens, ejecuciones, coste, preguntas al día,
     fallos seguidos).
   - Solo la persona cambia la configuración, la identidad y las órdenes, con recibo. **Soul no
     puede escribir nada de eso**, y nada de lo que recibe lo cambia. Así se cierra el ataque por
     guía inyectada documentado en OpenClaw.
   - El modo continuo exige doble opt-in (SPEC-186).
   - "PARA" desde cualquier canal detiene el bucle, cancela las ejecuciones activas y revoca las
     envolventes de Soul.
2. **Bucle.**
   - **Percibir**: eventos con hash. Lo que viene de otros bots o de las cúpulas es dato no
     fiable, nunca instrucción.
   - **Deliberar**: primero un triage determinista; luego un juicio con el modelo local,
     registrado como ejecución de evidencia, para que lo que Soul "pensó" se pueda auditar. La
     salida es una decisión estructurada: nada, avisar, preguntar, lanzar, responder a un bot o
     proponer.
   - **Actuar**: solo si la orden permite actuar y la acción cabe en su envolvente. Si no,
     pregunta a la operadora con opciones y recomendación. Nunca hace merge, push forzado,
     aprobación de PRs ni efectos externos sin admisión externa (AEK).
   - **Reflexionar**: propone memoria y skills; nunca las aplica sola.
   - Cada ciclo queda en el journal con sus entradas, su decisión, sus acciones y su coste.
   - Fail-safe: 3 fallos seguidos, la misma acción 3 veces o el presupuesto agotado lo detienen
     y avisan.
3. **Conversación.**
   - **Operadora**: chat libre en la web y en el móvil. Por mensajería, a través de Savia Relay,
     con gramática cerrada y botones (estado, despierta, duerme, para, agenda, presupuesto,
     aprueba o rechaza). Aprobar riesgo medio o alto exige biometría en el móvil (SE-430); un
     mensaje no basta.
   - **Bots**:
     - Agent Card propia y firmada, con habilidades de preguntar, informar y delegar.
     - Una delegación nunca se ejecuta directamente: se convierte en una propuesta que necesita
       una orden que la cubra o la aprobación de la operadora.
     - Bots en allowlist, con claves fijadas y presupuesto propio.
     - Anti-bucle: 8 turnos por conversación como máximo, 3 saltos y deduplicación.
     - Los bots sin A2A se conectan por el MCP de Space con un cliente registrado; nunca hay un
       bot sin identificar.
4. **Memoria y aprendizaje.**
   - Soul guarda su propio journal y sus notas, con procedencia y nivel.
   - Promover memoria a Savia o a una cúpula, o crear una skill (patrón Hermes), requiere dos
     cosas: superar casos dorados con el gate de calidad, y que la persona lo apruebe. Es la
     defensa contra la *skill misevolution* documentada.
   - La mejora de criterio se hace offline, con replay del journal (patrón OpenAI Five), y se
     propone como cambio revisable.
   - Prohibido auto-aprobarse más capacidad, presupuesto o autonomía.
5. **Encaje.**
   - Soul es un solicitante en términos de TEE: no emite autoridad.
   - Cuando AEOS exista, Soul le delega los flujos de varios pasos; nunca hay dos coordinadores
     sobre la misma ejecución.
   - Autonomía máxima L2 (actuar dentro de envolventes). Efectos externos bloqueados por
     ADR-002.

## Criterio de parada del producto

Si en dos semanas de piloto Soul genera más carga que valor (más preguntas o falsas alarmas que
acciones aceptadas), se reduce a bajo demanda y se revisa. Los resultados negativos se publican.

## Criterios de aceptación

- **AC1**: un mensaje de un bot que pide saltarse reglas o hacer merge no produce ninguna acción
  con efecto y queda registrado.
- **AC2**: Soul no puede escribir su configuración, su identidad ni sus envolventes.
- **AC3**: una acción fuera de la envolvente se convierte en pregunta con opciones y
  recomendación.
- **AC4**: 3 fallos seguidos detienen el bucle y avisan por todos los canales activos.
- **AC5**: "PARA" detiene el bucle, cancela ejecuciones y revoca envolventes en menos de 5 s.
- **AC6**: dos bots que se responden en bucle se cortan en el turno 8.
- **AC7**: una delegación de un bot sin orden que la cubra solo produce una propuesta.
- **AC8**: el presupuesto agotado detiene el bucle hasta el día siguiente o hasta una ampliación
  humana.
- **AC9**: una propuesta de skill que falla los casos dorados no llega a la persona.
- **AC10**: el replay de los ciclos reproduce las mismas decisiones del triage determinista.

## Entregas

- **S1**: bajo demanda en la web; observar e informar; disparadores deterministas.
- **S2**: órdenes permanentes con envolvente, chat en el móvil y avisos por Relay.
- **S3**: A2A de entrada y adaptador MCP para bots sin A2A.
- **S4**: modo continuo con latido, A2A de salida y propuestas de skills y memoria.

## Decisiones pendientes

- **D1**: addendum a ADR-002 para Soul (L2 con envolventes, sin efectos externos).
- **D2**: modo por defecto al instalar: apagado (propuesto) o bajo demanda.
- **D3**: transporte de Relay: Telegram primero (propuesto aquí; SE-406 recomienda WhatsApp Cloud
  API) o WhatsApp.
- **D4**: A2A de salida en S4 (propuesto) o nunca.
- **D5**: deliberación solo con modelo local (propuesto) o también con un perfil en la nube.

## OpenCode Implementation Plan

### Bindings touched

Ninguno directo: Soul vive en el servidor de Space. Sus tareas de agente usan el motor de SE-428
(OpenCode) con los plugins de Savia cargados; no añade hooks, agentes ni skills al workspace sin
aprobación.

### Verification protocol

- [ ] Escenarios AC1–AC10 con eventos sintéticos y un motor de prueba.
- [ ] Replay determinista del triage en CI.

### Portability classification

- [x] **PURE_BASH** (equivalente: servicio independiente del frontend; la parte de agente hereda
  la clasificación de SE-428)
