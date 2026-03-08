# Guía de flujo de datos

> 🦉 Soy Savia. Aquí te explico cómo se conectan las partes de pm-workspace. Cada dato que entra tiene un destino, y cada informe que sale tiene un origen. Nada se pierde, nada se duplica.

---

## Flujo 1: Horas → Costes → Facturas → Informes

```
Equipo imputa horas          Cost Management calcula         Facturación         Dirección
┌──────────────┐    ──→    ┌─────────────────┐    ──→    ┌──────────┐    ──→    ┌────────────┐
│ /report-hours│           │ coste/hora × h   │           │ facturas │           │ /ceo-report│
│ /savia-timesheet│        │ por proyecto     │           │ mensuales│           │ márgenes   │
└──────────────┘           └─────────────────┘           └──────────┘           └────────────┘
```

**Cómo funciona:** El equipo imputa horas contra PBIs (`/savia-timesheet` o integración Azure DevOps). El skill `cost-management` multiplica horas × coste/hora por perfil. Eso genera los datos de facturación. El `/ceo-report` agrega márgenes por proyecto.

**Ficheros involucrados:** `output/timesheets/` → cálculos en memoria → `output/reports/`

**Por qué importa:** Si las horas no se imputan, los costes son incorrectos, las facturas fallan y el informe de dirección no refleja la realidad.

---

## Flujo 2: Sprint → Velocity → Capacity → Alertas

```
Items del sprint         Velocity trend         Capacity forecast         Alertas
┌──────────────┐   ──→  ┌──────────────┐  ──→  ┌──────────────────┐  ──→  ┌────────────┐
│ /sprint-status│        │ story points  │       │ Monte Carlo sim  │       │ /ceo-alerts│
│ estados items │        │ últimos 6 sp  │       │ probabilidad     │       │ burnout    │
└──────────────┘        └──────────────┘       └──────────────────┘       └────────────┘
```

**Cómo funciona:** Cada sprint cierra con X story points completados. Eso alimenta la velocity trend (media móvil). Con esa velocity, `/capacity-forecast` simula Monte Carlo para predecir si el próximo sprint es viable. Si la velocity baja y las horas suben → alerta de burnout para el PM y CEO.

**Ficheros involucrados:** `.claude/commands/sprint-*.md` → `output/sprint-snapshots/` → alertas en `output/alerts/`

**Por qué importa:** Sin velocity histórica, no hay predicción. Sin predicción, el PM planifica a ciegas.

---

## Flujo 3: Spec → Código → Tests → Deploy → Métricas

```
Spec SDD generada      Agente implementa       Code review + tests      DORA metrics
┌──────────────┐  ──→  ┌──────────────┐  ──→  ┌──────────────────┐  ──→  ┌────────────┐
│ /spec-generate│       │ worktree      │       │ hooks pre-commit  │       │ /kpi-dora  │
│ contrato exec │       │ handlers+tests│       │ quality gates     │       │ lead time  │
└──────────────┘       └──────────────┘       └──────────────────┘       └────────────┘
```

**Cómo funciona:** El PO o Tech Lead genera una spec (`/spec-generate`). Un agente (o humano) implementa en un worktree aislado. Los hooks pre-commit validan tamaño, schema y reglas. Si pasan, se crea PR. El code review automático verifica contra reglas de dominio. Los tests actualizan cobertura. Todo se mide como DORA metrics.

**Ficheros involucrados:** `output/specs/` → `.claude/agents/developer-*.md` → `output/implementations/` → métricas en `/kpi-dora`

**Por qué importa:** Este es el flujo que permite que un "developer" sea humano o IA indistintamente. La spec es el contrato que garantiza calidad.

---

## Flujo 4: Memoria → Entidades → Continuidad

```
Decisiones del día       Memory store           Entity recall          Próxima sesión
┌──────────────┐   ──→  ┌──────────────┐  ──→  ┌──────────────┐  ──→  ┌──────────────┐
│ conversación  │        │ JSONL + hash  │       │ stakeholders  │       │ /context-load│
│ ADRs, cambios │        │ dedup + topic │       │ componentes   │       │ auto-inject  │
└──────────────┘        └──────────────┘       └──────────────┘       └──────────────┘
```

**Cómo funciona:** Durante la sesión, las decisiones se guardan en el memory store (JSONL con deduplicación por hash). Las entidades (stakeholders, componentes, servicios) se trackean con `/entity-recall`. Al iniciar una nueva sesión, `/context-load` inyecta el contexto relevante automáticamente. El hook post-compactación preserva la memoria entre sesiones.

**Ficheros involucrados:** `output/.memory-store.jsonl` → filtro por topic/project → inyección en contexto

**Por qué importa:** Sin memoria persistente, cada sesión empieza de cero. Con ella, Savia recuerda quién es cada stakeholder, qué se decidió, y por qué.

---

## Flujo 5: Mobile → Bridge → Claude CLI → Respuesta

```
App Savia Mobile       Savia Bridge           Claude Code CLI         Respuesta
┌──────────────┐  ──→  ┌──────────────┐  ──→  ┌──────────────┐  ──→  ┌──────────────┐
│ Chat SSE      │       │ HTTPS :8922   │       │ claude --session│      │ Stream SSE   │
│ POST /chat    │       │ Bearer token  │       │ --resume        │      │ texto → app   │
└──────────────┘       └──────────────┘       └──────────────┘       └──────────────┘
```

**Cómo funciona:** La app Savia Mobile envía mensajes vía HTTPS al Savia Bridge (puerto 8922). El Bridge autentica el request con Bearer token, abre una sesión en Claude Code CLI (`--session-id` primera vez, `--resume` después), y retransmite la respuesta como Server-Sent Events (SSE) al móvil en tiempo real.

**Ficheros involucrados:** App Android → `scripts/savia-bridge.py` → Claude CLI → respuesta SSE → persistencia local (Room DB cifrada con Tink)

**Por qué importa:** Extiende el acceso a pm-workspace fuera del terminal. Un PM puede consultar el estado del sprint, descomponer un PBI o revisar una decisión arquitectónica desde el móvil, sin necesitar SSH ni conocimientos técnicos profundos.

---

## Dependencias ocultas

Estas son señales cruzadas que detecto automáticamente:

- **Velocity baja + horas altas** = posible burnout → alerta al PM y CEO
- **Cobertura baja + PRs rápidos** = calidad en riesgo → alerta al Tech Lead
- **WIP alto + cycle time creciente** = cuello de botella → alerta al PO
- **Costes subiendo + velocity estable** = ineficiencia operativa → alerta CEO
- **Specs sin tests** = deuda técnica creciente → bloqueo por quality gate

---

## Mapa de ficheros

| Dato | Dónde se genera | Dónde se consume |
|---|---|---|
| Horas imputadas | `output/timesheets/` | cost-management, `/report-hours` |
| Costes por proyecto | cálculo en memoria | facturas, `/ceo-report` |
| Sprint snapshots | `output/sprint-snapshots/` | velocity, forecast, reports |
| Specs SDD | `output/specs/` | agentes developer, code review |
| Implementaciones | `output/implementations/` | tests, PRs, DORA |
| Memoria persistente | `output/.memory-store.jsonl` | context-load, entity-recall |
| Informes ejecutivos | `output/reports/` | CEO, stakeholders, clientes |
| Mobile → Bridge | `scripts/savia-bridge.py` | App Android, Room DB local |
