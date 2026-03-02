# Ejemplo de Implantación: SocialApp — Fase 2: Día a Día

> El flujo dual-track en acción: exploración y producción en paralelo, specs, gates, coordinación.
> Continuación de [12-ejemplo-implantacion-inicio.md](12-ejemplo-implantacion-inicio.md).

---

## Semana 2 — Dual-track en paralelo

El equipo ya tiene ritmo: Elena explora y escribe specs mientras Ana e Isabel construyen.

### Lunes: sync semanal (30 min)

Mónica abre la reunión con métricas:

```
Mónica → /flow-metrics
```

Savia muestra: Cycle Time 4 días (target 3-7 ✅), Throughput 2 items/semana (arrancando), Spec-Ready buffer 1 item (⚠️ target ≥3). Mónica detecta el problema: Elena necesita acelerar exploración.

```
Mónica → /flow-intake
```

Savia muestra 1 item Spec-Ready: "Profile Setup Wizard" (#1002). Ana tiene 1/2 WIP. Savia asigna #1002 → Ana. Mónica confirma.

**Decisión del sync**: Elena dedica 80% a exploración esta semana (buffer <3).

### Martes-Jueves: cada rol en acción

**Elena (exploración)** escribe specs del Outcome 2 (Social Feed):

```
Elena → /flow-spec --outcome "Social Feed"
```

Savia genera stub para "Timeline Feed". Elena completa: feed por follows + algoritmo, carga <500ms p95, Redis cache TTL 60s, MongoDB aggregation pipeline, event post.created → RabbitMQ. Escenarios Given/When/Then: feed vacío (nuevo usuario), feed con 1000+ posts (paginación), post con imagen (preview async).

Elena consulta con Isabel antes de marcar Spec-Ready:

```
Elena → "Isabel, ¿es viable MongoDB aggregation + Redis para el timeline?"
Isabel → "Sí, pero necesitamos índice compuesto en follows + created_at. Y el cache TTL debería ser 30s, no 60."
Elena → Actualiza spec, marca Spec-Ready ✅
```

**Ana (producción)** construye el Profile Setup Wizard (#1002):

```
Ana → /my-focus
```

Savia muestra: "Profile Setup Wizard — Ionic wizard 3 pasos (avatar, bio, interests). Spec #1002. Tasks: Ionic wizard component (4h), upload avatar con Capacitor (3h), integración user-service API (2h), tests E2E (2h)."

Ana trabaja en el wizard. Cuando completa los tasks, mueve el item a **Gates**.

**Isabel (producción)** termina auth-service (#1001) y lo pasa a Gates:

```
Isabel → mueve #1001 a Gates
```

### Los Quality Gates en acción

Cuando un item llega a **Gates**, Savia ejecuta la validación automática:

```
Savia (automático al mover a Gates) →
  Gate 1: Lint + format ✅ (2s)
  Gate 2: Unit tests 87% coverage ✅ (12s)
  Gate 3: Integration tests — auth-service + MongoDB ✅ (45s)
  Gate 4: Security — bcrypt rounds OK, rate limiting OK, CORS ✅ (30s)
  Gate 5: Pendiente review humano → asignar a Elena (QA)
```

**Elena (QA)** recibe la notificación de Gate 5:

```
Elena → revisa #1001 User Registration
  ✅ Flujo email registration: OK
  ✅ Flujo OAuth Google: OK
  ⚠️ Falta: mensaje de error cuando email ya registrado no es claro
  → Crea Bug #1010 vinculado a #1001, asigna a Isabel (2h)
```

Elena mueve #1001 a **Deployed** (con el bug como follow-up, no bloquea deploy a DEV).

---

## Semana 3 — Coordinación front ↔ back

### El patrón "API contract first"

Isabel empieza la spec "Timeline Feed" (#1003). El front (Ana) necesita el API para construir la pantalla. Savia facilita:

```
Isabel → /pbi-decompose --id 1003
```

Tasks generados: 1.1 modelo Post + MongoDB (4h, Isabel), 1.2 GET /feed + paginación (4h, Isabel) ← **API contract**, 1.3 event post.created → RabbitMQ (3h, Isabel), 2.1 Ionic timeline + infinite scroll (6h, Ana) ← depende de 1.2, 2.2 integración API (3h, Ana) ← depende de 1.2.

**Clave**: Isabel entrega el **API contract** (task 1.2) primero. Ana puede empezar con mock mientras Isabel implementa, y conectar cuando el endpoint esté listo.

```
Isabel → completa task 1.2 (API contract publicado en Swagger)
Isabel → avisa a Ana: "GET /feed listo en DEV, Swagger actualizado"
Ana → cambia de mock a API real, continúa con infinite scroll
```

### Cómo Savia ayuda a detectar bloqueos

Jueves, Mónica hace check rápido:

```
Mónica → /flow-board
```

Savia muestra:

```
EXPLORACIÓN                              │ PRODUCCIÓN
Discovery   Spec-Writing   Spec-Ready    │ Ready    Building    Gates     Deployed
────────────────────────────────────────────────────────────────────────────────────
DMs (#1005)  Reactions(#1004)  ──         │  ──     Timeline   Profile    Registration
                                         │          (#1003)   (#1002)    (#1001)
                                         │         Ana+Isabel  Ana 🔴     ──

⚠️ Spec-Ready buffer: 0 items — Elena debe priorizar exploración
⚠️ Ana: Profile (#1002) en Gates >2 días — verificar Gate 5
```

Mónica actúa: "Elena, ¿puedes marcar Spec-Ready la de Reactions hoy? Ana se va a quedar sin trabajo pronto." Elena acelera.

---

## Cómo se ve una semana tipo

**Lun**: Sync 30min (todos) → Mónica: `/flow-metrics` + `/flow-intake`. **Mar-Jue**: Elena en discovery/specs, Ana+Isabel building, Mónica oversight + desbloqueo. Mónica hace spec review con Elena el miércoles. El jueves `/flow-board` para detectar stuck. **Vie**: Elena QA gates, Ana+Isabel PR review + deploy DEV, Mónica métricas.

### Interacción con agentes

Isabel genera specs ejecutables para agentes: `/spec-generate --task 1003-1 --type agent-single`. Savia genera spec para feed-service, Isabel revisa contrato y lanza al agente. Ana usa `/spec-generate --task 1003-2 --type human` (tipo human porque el infinite scroll tiene matices UX).

> **Continúa en** [14-ejemplo-implantacion-release.md](14-ejemplo-implantacion-release.md)
