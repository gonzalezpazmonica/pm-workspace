---
status: PROPOSED
priority: P1
developer_type: agent-single
created: 2026-10-02
author: Savia
phase: A
risk: L3
related_specs: [SE-428, SE-430, SE-423, SE-401]
origin: "Mandato de la operadora 2026-10-02: Savia Space con API JWT y contrato OpenAPI, MCP y A2A para ser consumido, ejecutado y usado por terceras aplicaciones, agentes o servicios; compatible con AEK, AEOS y TEE"
resource: https://spec.openapis.org/oas/v3.1.0
---

# SE-429 — Savia Space interoperable: API con JWT y OpenAPI, MCP y A2A

## Problema

Savia Space (SE-428) se diseña para su propia interfaz web, con una cookie local. Sin esta spec no podrían usarlo:

- otras aplicaciones: scripts, paneles, la app móvil;
- otros agentes: OpenCode, Claude Code u otros clientes MCP;
- otros servicios: coordinadores A2A como AEOS.

## Objetivo

Exponer el mismo núcleo de Space por tres protocolos, con un solo contrato y un solo modelo de
seguridad. Las restricciones de partida:

- **No ampliar la autoridad.** Space no emite permisos de efectos; los verifica cuando un emisor
  externo aprobado los aporta.
- **No debilitar la promesa central.** Lo que el modelo recibe es lo que alguien con autoridad
  aprobó.

## Diseño

1. **Un núcleo, tres adaptadores.**
   - REST, MCP y A2A comparten el mismo conjunto de JSON Schema 2020-12, la autorización, la
     idempotencia, el journal, los errores y la auditoría.
   - La misma suite de escenarios se ejecuta contra los tres.
2. **API REST con contrato OpenAPI 3.1.**
   - Contract-first, con validación de cada respuesta en los tests y tipos de cliente generados
     (TypeScript y Kotlin).
   - `/api/v1` solo crece con campos opcionales. Lo incompatible va a `/v2`, con cabeceras
     `Deprecation` y `Sunset`.
3. **Tokens JWT.** Space es servidor de recursos. Access tokens RFC 9068 con estas reglas:
   - **Firma**: EdDSA por defecto y ES256 para dispositivos. Allowlist por emisor; nunca `none`
     ni HMAC. Claves desde un JWKS fijado en la configuración, nunca desde cabeceras del token.
   - **Validez**: 300 s como máximo.
   - **Audiencia**: la de la instancia (RFC 8707).
   - **Claims**: `iss sub aud exp iat jti client_id scope`; opcionales `act` (RFC 8693, agente que
     actúa por una persona), `cnf` (DPoP) y nivel máximo de confidencialidad.
   - **Tipos rechazados**: tokens de identidad (ID tokens, aserciones de identidad) y credenciales
     de otros servicios.
   - **Emisor local mínimo**: solo para clientes que la persona registra (`client_credentials` con
     `private_key_jwt`). Sin contraseñas, flujos de navegador ni refresh tokens. Con un emisor
     externo de identidad, Space queda solo como servidor de recursos.
   - **Metadatos de recurso protegido** (RFC 9728) y JWKS públicos.
   - **Sin reenvío del token del llamante** a ningún servicio interno.
4. **Autorización.**
   - Scopes por operación. Aprobar ejecuciones o responder permisos nunca se deduce de otro
     scope.
   - Nivel efectivo = mínimo de persona, cliente y token. Lo que está por encima no existe para
     ese cliente.
   - Cada sesión pertenece al cliente que la creó, salvo que la persona la comparta.
   - Cuotas por cliente.
5. **Aprobación con terceros.** Tres modos registrados en cada ejecución:
   - **Persona**: la petición espera; la persona la abre, Space prepara de nuevo y ella aprueba
     los bytes frescos desde la web o el móvil.
   - **Delegación acotada**: la persona registra el cliente con una envolvente (tareas,
     proyectos, modelos locales, nivel, frecuencia y caducidad ≤ 30 días). Es una garantía más
     débil y la interfaz lo dice. Prohibida si los datos salen a un proveedor en la nube.
   - **Lease externo**: un Authority Lease de un emisor aprobado (AEK). Space lo verifica, con
     comprobación de revocación fresca antes de enviar, y lo consume una vez. Bloqueado hasta que
     exista el contrato aprobado. Space nunca emite leases.
6. **MCP.**
   - Servidor stdio para agentes locales (0.2) y Streamable HTTP como servidor de recursos OAuth
     (0.3).
   - Tools tipadas con anotaciones de solo lectura donde corresponde; ninguna bloquea más de 30 s.
   - Recursos con suscripción y un prompt por tarea predefinida.
   - El texto de las fuentes viaja marcado como no fiable.
7. **A2A.**
   - Agent Card firmada.
   - Una tarea A2A es una ejecución de Space. Mientras falta una aprobación, un permiso o una
     respuesta, queda en `input-required`.
   - Artefactos de respuesta, evidencia, diff y recibo.
   - Streaming por SSE con la secuencia del journal.
   - Notificaciones push solo a URLs en allowlist, firmadas y sin contenido sensible (0.4).
8. **Compatibilidad con TEE v1.1, AEK y AEOS.**
   - Space produce **recibos firmados** de decisión, de envío al proveedor y de tareas de agente
     (SE-428). Referencian hashes, nunca el texto de las fuentes.
   - Correspondencia con TEE:
     - el prompt preparado es la intención;
     - la tarea predefinida es la clase de decisión;
     - la aprobación es el compromiso, y la admisión de la ejecución es el punto de enforcement;
     - las capturas con hash son el límite de contexto;
     - la validación determinista y la revisión humana son el outcome.
   - AEK es el emisor y verificador de autoridad de efectos. Space solo consume y verifica leases
     mediante un adaptador al contrato que se apruebe, fuera del repositorio público si ese
     contrato es privado.
   - AEOS usa Space como worker por A2A:
     - un solo coordinador por ejecución;
     - claves de idempotencia derivadas del paso del flujo, sin reenvíos;
     - las referencias del flujo son correlación, no autoridad.
9. **Red.**
   - Fuera de loopback: TLS 1.3 con certificado fijado y DPoP obligatorio. Solo API con bearer;
     nunca la interfaz web con cookie.
   - Internet directo bloqueado hasta tener un modelo de amenazas remoto y un emisor de identidad
     externo. El acceso remoto recomendado es por VPN.

## Criterios de aceptación

- **AC1**: un token con otra audiencia, con algoritmo no permitido o caducado se rechaza en REST,
  MCP y A2A.
- **AC2**: un cliente sin el scope de aprobar no puede crear una ejecución.
- **AC3**: la delegación fuera de la envolvente se rechaza.
- **AC4**: la misma aprobación repetida no crea dos ejecuciones.
- **AC5**: un cliente de nivel N1 no ve capturas N2.
- **AC6**: un cliente revocado deja de funcionar en la siguiente petición.
- **AC7**: una tarea A2A pasa por `input-required` → `working` → `completed` con artefactos de
  evidencia.
- **AC8**: una tool MCP de ejecución responde en menos de 1 s con el identificador y notifica el
  progreso.
- **AC9**: una petición con `Origin` ajeno se rechaza antes de leer el cuerpo.
- **AC10**: los recibos verifican con el JWKS de la instancia y un byte alterado rompe la firma.
- **AC11**: un lease revocado entre la aprobación y el envío impide el envío.
- **AC12**: un coordinador que repite el mismo paso obtiene la misma tarea y un solo envío.

## Decisiones pendientes

- **D1**: emisor local mínimo en 0.2 (propuesto) o esperar a un emisor externo.
- **D2**: delegación acotada en 0.2 (propuesto) o solo aprobación de persona hasta tener leases.
- **D3**: contrato OpenAPI contract-first (propuesto) o generado desde el código.
- **D4**: recibos firmados en 0.2 (propuesto) o con A2A en 0.3.

## Entregas

- **0.2**: REST con JWT y OpenAPI, MCP stdio, aprobación de persona y delegación acotada,
  recibos.
- **0.3**: MCP HTTP, A2A en loopback, Agent Card firmada, prueba de AEOS en modo solo lectura.
- **0.4**: red local y VPN con TLS fijado y DPoP; notificaciones push.
- **Leases externos**: bloqueados hasta el contrato de AEK.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode |
|---|---|---|
| Servidor MCP `savia-space` (stdio) | registrado como servidor MCP en la configuración del proyecto | registrado como servidor MCP local en `opencode.json` |
| Hooks, agentes y skills | sin cambios | sin cambios |

### Verification protocol

- [ ] La misma suite de escenarios contra REST, MCP y A2A.
- [ ] El servidor MCP se prueba desde Claude Code y desde OpenCode con un token de cliente
  registrado.
- [ ] Sin hooks nuevos.

### Portability classification

- [x] **DUAL_BINDING**: el servidor MCP es un binario independiente del frontend y se registra
  igual en ambos.
