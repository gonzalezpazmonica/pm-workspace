---
status: PROPOSED
---

# SPEC-SE-014 — Release Orchestration

> **Priority:** P1 · **Estimate (human):** 8d · **Estimate (agent):** 8h · **Category:** complex · **Type:** release lifecycle + multi-tenant deployment

## Objective

Dar a una consultora de 5000 personas un sistema agéntico de orquestación de
releases **multi-tenant, auditable, rollback-safe y air-gap ready** que coordine
despliegues de entregables a clientes en entornos heterogéneos (cloud público,
on-prem, soberano) sin introducir SaaS intermedios ni telemetría externa.

El problema real: en consultora grande, el mismo artefacto se despliega con
variantes a N clientes con SLAs, ventanas de cambio y compliance distintos.
Una release que a un banco regulado por DORA va por blue/green con rollback
forzoso a otra startup va por rolling con canary 10%. Hoy esto vive en hojas
de cálculo, Confluence y cabezas. Savia lo convierte en **Release-as-Code**:
un plan de release por tenant, en `.md`, versionado, validado y ejecutable por
agentes con gates humanos en cada paso irreversible.

## Principles affected

- **#1 Soberanía del dato** — el plan de release es `.md` local del tenant, no un registro propietario en una plataforma SaaS
- **#2 Independencia del proveedor** — adaptadores a Azure DevOps Release, GitHub Actions, Argo CD, Spinnaker, Octopus Deploy; jamás acoplados
- **#4 Privacidad absoluta** — ninguna release telemetry sale del entorno del cliente; modo air-gap firstclass
- **#5 El humano decide** — Deploy a producción SIEMPRE con gate humano; rollback puede iniciarse autónomo pero se audita

## Design

### Release-as-Code — el artefacto central

Cada release vive en el tenant del cliente como un árbol `.md`:

```
tenants/{tenant-id}/releases/{release-id}/
├── release-plan.md          # Contrato ejecutable (YAML + prosa)
├── change-window.md         # Ventana acordada + aprobaciones CAB
├── canary-config.md         # Estrategia canary/blue-green/rolling
├── rollback-playbook.md     # Pasos de reversión probados
├── feature-flags.md         # Flags activados/desactivados
├── approvals.md             # Chain of custody: quién aprobó qué y cuándo
├── postmortem.md            # (post-deploy) resultados y lecciones
└── signed.sig               # Firma criptográfica de la release autorizada
```

El `release-plan.md` tiene frontmatter YAML parseable + prosa humana:

```yaml
---
release_id: "2026-04-15-savia-web-4.44.0"
tenant: "acme-banking"
artifact: "savia-web@4.44.0"
environment: "prod-eu-west"
strategy: "blue-green"
canary_percent: 0
change_window:
  start: "2026-04-15T22:00:00+02:00"
  end:   "2026-04-16T02:00:00+02:00"
  cab_ticket: "CAB-9912"
compliance_profile: "dora-banking"
rollback:
  auto_trigger_on:
    - metric: "error_rate"
      threshold: "> 2% sustained 5min"
    - metric: "p95_latency_ms"
      threshold: "> 800 sustained 10min"
  max_rto_minutes: 15
approvals_required:
  - role: "release_manager"
  - role: "client_change_authority"
  - role: "security_officer"
    conditions: ["compliance_profile:dora-banking"]
feature_flags:
  - name: "new_auth_flow"
    state: "on"
    rollout_percent: 100
---

# Release 4.44.0 — Savia-Web (Acme Banking)
...prosa: contexto, riesgos, dependencias, runbook...
```

### Perfiles de compliance por cliente

Un tenant declara su `compliance_profile.md` y las releases heredan gates automáticos:

| Perfil | Industria típica | Gates automáticos |
|--------|------------------|-------------------|
| `standard` | SMB, startups | Canary 10% → 50% → 100%, rollback manual |
| `dora-banking` | Banca EU | Blue/green obligatorio, CAB ticket, 2 aprobaciones, postmortem |
| `hipaa-health` | Salud US | Audit log firmado, PHI scan pre-deploy, BAA vigente |
| `gdpr-eu` | Cualquier EU con PII | DPIA vigente, retention check |
| `nis2-critical` | Infraestructura crítica EU | Test de resiliencia pre-deploy, notificación reguladora si falla |
| `airgap` | Defensa, gobierno | Todo por artifact firmado, sin red externa |

### Agentes nuevos

| Agente | Nivel | Propósito |
|--------|-------|-----------|
| `release-orchestrator` | L2 | Valida plan, coordina gates, ejecuta estrategia vía adapter |
| `release-validator` | L1 | Verifica compliance profile, change window, approvals antes de ejecutar |
| `rollback-executor` | L3 | Ejecuta rollback-playbook cuando se disparan thresholds; SIEMPRE notifica humano |
| `release-postmortem` | L2 | Post-deploy genera `postmortem.md` con métricas y lecciones |

### Adaptadores (SE-003 MCP catalog extension)

Pluggables, uno por herramienta de release:

- `mcp-server-azdo-release` — Azure DevOps Release Pipelines
- `mcp-server-github-deploy` — GitHub Actions Deployments API
- `mcp-server-argocd` — Argo CD (GitOps)
- `mcp-server-spinnaker` — Spinnaker pipelines
- `mcp-server-octopus` — Octopus Deploy

El adaptador es **solo-lectura/escritura controlada**: Savia NUNCA hace `kubectl apply` directo; siempre delega al sistema de release del cliente vía su MCP.

### Comandos nuevos

```
/release-plan {tenant} {artifact} {version}     # Genera release-plan.md con agentes
/release-validate {tenant} {release-id}         # Verifica gates antes de ejecutar
/release-execute {tenant} {release-id}          # Ejecuta respetando gates (requiere approval chain)
/release-rollback {tenant} {release-id}         # Dispara rollback-playbook
/release-postmortem {tenant} {release-id}       # Genera postmortem desde métricas
/release-calendar {tenant}                      # Vista de change windows del tenant
/portfolio-releases                             # Vista cross-tenant (Program Mgr)
```

### Savia-web integration

Nueva sección **Releases** en Savia-web:

- Release calendar por tenant (timeline visual)
- Gate board (qué release espera qué aprobación)
- Canary live dashboard (métricas en curso)
- Approval workflow (firma con token del IdP del tenant, SE-007)
- Postmortem library cross-tenant (agregada con masking SE-010)

**Zero cliente data en Savia-web central**: cuando el despliegue es multi-tenant,
Savia-web agrega solo metadatos (release-id, status, fecha); el contenido real
vive en el tenant. Arquitectura federada.

### Roles involucrados (no solo devs)

| Rol | Uso | Acción esperada |
|-----|-----|-----------------|
| Release Manager | Crea plan, coordina CAB | Owner del release-plan.md |
| Client Change Authority | Aprueba ventana | Firma gate `client_change_authority` |
| Delivery Manager | Confirma readiness del equipo | Valida dependencies listas |
| DevOps/SRE | Ejecuta vía adapter | Monitoriza canary live |
| Security Officer | Firma compliance gates | Valida profile antes de deploy |
| PM | Visibilidad en sprint board | Release aparece en burndown |
| Account Executive | Status al cliente | Lee release status para briefings |
| Quality Manager | Post-release quality gate | Dispara `release-postmortem` |
| PMO | Portfolio view | `/portfolio-releases` cross-tenant |
| CFO/Finance | Revenue recognition trigger | `release_completed` emite evento para SE-018 billing |

### Configuration

En `pm-config.md`:

```
RELEASE_ORCHESTRATION_ENABLED = true
RELEASE_DEFAULT_PROFILE       = "standard"
RELEASE_REQUIRE_CAB_FOR       = ["dora-banking", "nis2-critical", "hipaa-health"]
RELEASE_ROLLBACK_AUTO_MAX_RTO = 15     # minutos; superior requiere humano
RELEASE_AIRGAP_MODE           = false  # activar para defensa/gobierno
```

## Components

| Name | Kind | Purpose |
|------|------|---------|
| `docs/rules/domain/release-orchestration.md` | rule | Contrato Release-as-Code, perfiles compliance, flujo de gates |
| `.claude/agents/release-orchestrator.md` | agent | L2 orquestador principal |
| `.claude/agents/release-validator.md` | agent | L1 validador pre-ejecución |
| `.claude/agents/rollback-executor.md` | agent | L3 ejecutor de rollback con gate humano |
| `.claude/agents/release-postmortem.md` | agent | L2 analizador post-deploy |
| `.claude/commands/release-plan.md` | command | `/release-plan` |
| `.claude/commands/release-validate.md` | command | `/release-validate` |
| `.claude/commands/release-execute.md` | command | `/release-execute` |
| `.claude/commands/release-rollback.md` | command | `/release-rollback` |
| `.claude/commands/release-postmortem.md` | command | `/release-postmortem` |
| `.claude/commands/release-calendar.md` | command | `/release-calendar` |
| `.claude/commands/portfolio-releases.md` | command | `/portfolio-releases` |
| `.claude/skills/release-orchestration/SKILL.md` | skill | Pipeline de 5 fases: plan→validate→execute→monitor→postmortem |
| `.claude/skills/release-orchestration/references/compliance-profiles.md` | ref | 6 perfiles documentados |
| `templates/release-plan.template.md` | template | Skeleton YAML+prosa |
| `templates/rollback-playbook.template.md` | template | Skeleton runbook |
| `scripts/release-validate-gates.sh` | script | Verificador determinista de gates antes de ejecutar |
| `tests/test-release-orchestration.bats` | test | ≥20 tests, score SPEC-055 ≥ 80 |

## Contracts

**Schema de `release-plan.md` frontmatter** (canonical, validado por JSON Schema):
ver diseño arriba. Campos obligatorios: `release_id`, `tenant`, `artifact`,
`environment`, `strategy`, `change_window`, `compliance_profile`,
`approvals_required`, `rollback`.

**Evento emitido a bus local tras deploy exitoso:**
```json
{"event":"release.completed","tenant":"acme","release_id":"...","artifact":"savia-web@4.44.0","completed_at":"2026-04-15T23:47:12Z","triggered_by":"release-orchestrator"}
```
Este evento es consumido por SE-018 (billing revenue recognition) y SE-019 (evaluation baseline).

**Rollback trigger:** sólo el agente `rollback-executor` puede ejecutar rollback
automáticamente, y SIEMPRE notifica humano en el mismo tick. No hay rollback silencioso.

## Acceptance criteria

1. Regla `docs/rules/domain/release-orchestration.md` ≤150 líneas documenta flujo, 6 perfiles compliance, gates
2. `release-orchestrator` agente creado con L2, `token_budget` declarado, tests unitarios
3. Comando `/release-plan` genera un `release-plan.md` válido para tenant de ejemplo con un solo comando
4. Comando `/release-validate` detecta 10 tipos de incumplimiento (gates faltantes, profile mismatch, change window expirada, approval chain incompleta…)
5. `scripts/release-validate-gates.sh` falla con exit 2 y mensaje específico cuando faltan gates; pasa cuando todo ok
6. Al menos 2 adapters MCP funcionales (Azure DevOps Release + GitHub Deployments) — reutilizan SE-003
7. `rollback-executor` NUNCA ejecuta sin logear notificación a humano; test verifica el log
8. Savia-web tiene ruta `/releases` con lista, filtro por tenant, y detail view de release-plan
9. Tests BATS ≥20, score SPEC-055 ≥80, coverage delta ≥0
10. Modo air-gap: toda la feature funciona sin salida a internet (validado con test offline)
11. Event `release.completed` emitido y consumible por SE-018 mock
12. `pr-plan` pasa 11/11 gates

## Out of scope

- Implementar los 5 adapters MCP (solo 2 funcionales, resto como stub + documentación)
- UI visual de pipeline en Savia-web (v1 es lista + detail; visual pipeline en v2)
- Integración con sistemas de ticketing CAB (ServiceNow, Remedy) — queda como adapter futuro
- Orquestación cross-cloud activa (multi-region deployment coordinator) — follow-up
- Predicción de blast radius con ML

## Dependencies

- **Blocked by:** SE-001 (layer contract), SE-002 (multi-tenant isolation), SE-003 (MCP catalog base)
- **Blocks:** SE-018 (billing necesita `release.completed` para revenue recognition), SE-019 (evaluation usa release history como baseline)
- **Soft deps:** SE-009 (observability para alimentar canary metrics)

## Migration path

- Reversible: feature-flag `RELEASE_ORCHESTRATION_ENABLED=false` → todo desactivado, pm-workspace sigue igual
- Migración desde Confluence/Sheets: script `scripts/migrate-release-history.sh` lee CSV y genera `.md` históricos (opcional, client-side)
- Coexistencia con Azure DevOps Release existente: Savia genera el plan, Azure DevOps ejecuta; ambas fuentes de verdad se sincronizan vía adapter

## Impact statement

Convierte la orquestación de releases —hoy un conjunto de hojas Excel, tickets y
conversaciones en Teams— en contratos ejecutables versionados con gates humanos
auditables. Para una consultora de 5000 personas con 200+ clientes activos, la
reducción de incidentes de release mal coordinada y la trazabilidad de compliance
valen la diferencia entre pasar o suspender una auditoría DORA/NIS2.

Las ganancias clave: (1) zero data leakage entre tenants, (2) rollback verificable,
(3) evidencia de compliance sin telemetría, (4) agentic accompaniment que no
sustituye a humanos sino que elimina el trabajo manual repetitivo (redacción de
runbooks, verificación de gates, generación de postmortems).

## Sources

- ITIL 4 Change Enablement practice
- ISO/IEC 20000-1:2018 (Service Management)
- EU DORA (Regulation 2022/2554) — operational resilience for financial sector
- NIS2 Directive (EU 2022/2555) — network and information security
- Google SRE Book, ch. "Release Engineering"
- Spinnaker deployment strategies documentation
- Argo CD progressive delivery patterns
