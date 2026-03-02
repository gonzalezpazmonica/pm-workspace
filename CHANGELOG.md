# Changelog

All notable changes to PM-Workspace.
Format: [Keep a Changelog](https://keepachangelog.com). Versioning: [SemVer](https://semver.org).

---

## [0.75.0] — 2026-03-02

Savia E2E Test Harness — Entorno Docker aislado con agente autónomo que ejecuta Claude Code headless contra pm-workspace. Simula los 4 roles del equipo SocialApp (Mónica, Elena, Ana, Isabel) ejecutando 23 pasos en 5 escenarios (setup → exploration → production → coordination → release). Recopila métricas de tokens, tiempos, errores y bloqueos de contexto. Modo mock para CI, modo live con API key real.

### Added

- **`docker/savia-test/`** — Test harness Docker: Dockerfile, docker-compose.yml, harness.sh orchestrator.
- **5 escenarios E2E** — 00-setup (3 pasos), 01-exploration (5), 02-production (5), 03-coordination (5), 04-release (5). 23 pasos totales cubriendo todo el ciclo Savia Flow.
- **Motor mock** — Simula respuestas con tokens aleatorios, 5% error rate (context overflow + timeout). Para CI sin API key.
- **Motor live** — Ejecuta `claude -p` headless real. Captura tokens, duración, errores. Configurable via env vars.
- **Métricas CSV** — scenario, step, role, command, tokens_in, tokens_out, duration_ms, status, error.
- **Informe automático** — report.md generado al final con resumen, failures, errors, token totals.

[0.75.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.74.0...v0.75.0

---

## [0.74.0] — 2026-03-02

Savia Flow Practice — Implementación práctica de la metodología Savia Flow: configuración Azure DevOps dual-track, tablero exploración/producción, intake continuo, métricas de flujo y creación de specs. Ejemplo completo: SocialApp (Ionic + microservicios + RabbitMQ) con equipo de 4 personas.

### Added

- **`/flow-setup`** — Configurar Azure DevOps para Savia Flow: board dual-track (Exploration + Production), campos custom (Track, Outcome ID, Cycle Time), area paths. Modos: `--plan` (preview), `--execute` (aplicar), `--validate` (verificar).
- **`/flow-board`** — Visualizar tablero dual-track: exploración a la izquierda, producción a la derecha. Alerta WIP limits excedidos. Filtros por track y persona.
- **`/flow-intake`** — Intake continuo: mover items Spec-Ready a Production. Valida acceptance criteria, check capacidad, asigna a builder disponible.
- **`/flow-metrics`** — Dashboard métricas de flujo: Cycle Time, Lead Time, Throughput, CFR. Métricas IA: spec-to-built time, handoff latency. Tendencias y comparativas.
- **`/flow-spec`** — Crear spec ejecutable desde outcome de exploración. Genera stub con 5 secciones Savia Flow, crea User Story vinculada al Epic padre.
- **Skill `savia-flow-practice/`** — Guía práctica con 6 references: azure-devops-config, backlog-structure, task-template-sdd, meetings-cadence, dual-track-coordination, example-socialapp.

### Changed

- Command count: 262 → 267 (+5 comandos flow)
- Skills: 20 → 21 (+savia-flow-practice)
- Context-map: añadido grupo Savia Flow

[0.74.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.73.0...v0.74.0

---

## [0.73.0] — 2026-03-02

Vertical Banking — Herramientas especializadas para equipos de desarrollo en banca: validación BIAN + ArchiMate, pipelines Kafka/EDA, data governance (lineage, clasificación, GDPR), auditoría MLOps (model risk, XAI, scoring). Auto-detección de proyectos bancarios.

### Added

- **`/banking-detect`** — Auto-detección de proyecto bancario. 5 fases: entidades BIAN (Account, Settlement, KYC/AML), rutas API bancarias, deps (Kafka, Snowflake, MLflow), config (BIAN_*, KAFKA_*, SWIFT_*), documentación. Score ≥55% → confirmar.
- **`/banking-bian`** — Validar arquitectura contra estándar BIAN. Mapeo microservicios a Service Domains (Payments, Settlement, Deposits, Lending, Risk). Diagrama ArchiMate en Mermaid. Detección de anti-patrones (God Service, Fragmented Domain).
- **`/banking-eda-validate`** — Validar pipelines Kafka/MSK/AMQ: topologías, DLQ, schemas Avro/Protobuf, idempotencia, ordering guarantees. Evaluar patrones EDA: Saga, CQRS, Event Sourcing. Circuit breakers en settlement flows.
- **`/banking-data-governance`** — Auditar data governance: lineage (BCBS 239), clasificación (PII/PCI/Confidencial), catálogo Snowflake/Iceberg, feature stores (batch + real-time). Validar GDPR/LOPD. Data mesh domain ownership.
- **`/banking-mlops-audit`** — Auditar pipeline MLOps bancario: versionado, CI/CD/CT, drift detection, model registry. Explicabilidad (XAI/SHAP/LIME). Model risk management (SR 11-7). Scoring architectures (batch/streaming/event-driven). GenAI (RAG, embeddings).
- **Skill `banking-architecture/`** — Skill con 3 references: BIAN framework, EDA patterns banking, data governance banking.
- **Regla `banking-detection.md`** — Regla de detección automática de proyectos bancarios con 5 fases y scoring.

### Changed

- Command count: 257 → 262 (+5 comandos banking)
- Context-map: añadido grupo Banking
- CLAUDE.md: añadida sección Banking Architecture

[0.73.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.72.0...v0.73.0

---

## [0.72.0] — 2026-03-02

Trace Intelligence — Búsqueda y análisis profundo de trazas distribuidas, investigación asistida de errores con root cause analysis, correlación multi-fuente de incidentes. Era 13 — Observability & Intelligence (2/2). ERA 13 COMPLETE!

### Added

- **`/trace-search {criterio}`** — Buscar y filtrar trazas en Grafana Tempo, Datadog APM, Azure App Insights, OpenTelemetry. Soporta búsqueda en lenguaje natural. Filtros: servicio, estado (error/slow), periodo temporal, código error, tipo de excepción, usuario. Resultados con paginación automática.
- **`/trace-analyze {trace-id}`** — Análisis profundo de traza específica. Waterfall ASCII timeline, detección de cuellos de botella (span más lento), cadena de errores (origen y propagación), detección de anomalías vs baseline, mapa de dependencias de servicios, recomendaciones contextuales. Output adaptado por rol.
- **`/error-investigate {descripción}`** — Investigación asistida de errores. Busca logs coincidentes, correlaciona trazas, analiza despliegues recientes, verifica métricas de infraestructura, identifica servicio origen, construye hipótesis de root cause, sugiere mitigación inmediata y preventiva.
- **`/incident-correlate [--incident-id ID]`** — Correlación cruzada de métricas (Grafana, Datadog, App Insights), logs (Loki, Datadog, App Insights), trazas (Tempo, APM, Dependencies), despliegues (CI/CD), alertas previas y cambios de configuración. Genera timeline unificado, detecta cascading failures, cuantifica blast radius, draft de post-mortem automático.

### Changed

- Command count: 253 → 257 (+4 comandos trace intelligence)
- Era 13 (Observability & Intelligence): COMPLETE! (2/2)

[0.72.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.71.0...v0.72.0

---

## [0.71.0] — 2026-03-02

Observability Core — Conexión a Grafana, Datadog, Azure App Insights, OpenTelemetry. Consultas en lenguaje natural a datos de observabilidad (PromQL, KQL, Datadog Query Language). Dashboards digeridos por rol (CEO, CTO, PM, Dev, QA, SRE). Health checks de fuentes. Era 13 — Observability & Intelligence (1/2).

### Added

- **`/obs-connect {platform}`** — Conectar Savia a Grafana, Datadog, App Insights, OpenTelemetry. Almacena credenciales cifradas (AES-256-CBC). Soporta múltiples instancias simultáneamente. Test de conexión automático.
- **`/obs-query {pregunta}`** — Consultas en lenguaje natural a datos de observabilidad. Traduce automáticamente a PromQL (Grafana), KQL (App Insights), Datadog Query Language. Detecta anomalías vs baseline. Correlaciona con deployments.
- **`/obs-dashboard [--role]`** — Dashboard digerido por rol. CEO: disponibilidad + SLA + costos. CTO: latencias por servicio + errors. PM: impacto en usuarios + features. Dev/SRE: detalles técnicos + logs/traces. QA: pre/post deploy comparisons.
- **`/obs-status`** — Health check de todas las fuentes conectadas. Estado de conexión, última sincronización, volumen de datos, alertas activas, recomendaciones.

### Changed

- Command count: 249 → 253 (+4 comandos observabilidad)
- Era 13 (Observability & Intelligence): iniciada (1/2)

[0.71.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.70.0...v0.71.0

---

## [0.70.0] — 2026-03-02

Multi-Tenant & Skills Marketplace — Workspaces aislados por departamento/equipo, marketplace interno de skills/playbooks, compartición de recursos con control de aprobación. Era 12 — Team Excellence & Enterprise (5/5). PLAN COMPLETADO: v0.54-v0.70 = 68 comandos en 17 versiones.

### Added

- **`/tenant-create`** — Crea workspace aislado por departamento con perfiles, roles, configuración de proyecto e herencia empresarial. Isolation levels: full (separado) o shared (datos separados, reglas comunes).
- **`/tenant-share`** — Comparte recursos (playbooks, templates, skills, reglas) entre tenants con flujo de aprobación, versionado y prevención de config drift.
- **`/marketplace-publish`** — Publica skills/playbooks al marketplace interno con metadatos, validación de calidad y sistema de ratings tipo Anthropic Skills.
- **`/marketplace-install`** — Instala recursos del marketplace con resolución de dependencias, preview y rollback automático. Verificación de compatibilidad.

### Changed

- Command count: 249 → 253 (+4 comandos multi-tenant y marketplace)
- Era 12 (Team Excellence & Enterprise): ahora completa (5/5 fases)

### Plan Roadmap Completado

**v0.54–v0.70**: 17 versiones, 68 nuevos comandos estructurados en 4 eras:
- Era 9 (v0.54–v0.57): Company Intelligence — 16 comandos
- Era 10 (v0.58–v0.61): AI Governance — 17 comandos
- Era 11 (v0.62–v0.65): Context Engineering 2.0 — 17 comandos
- Era 12 (v0.66–v0.70): Team Excellence & Enterprise — 18 comandos

**Total**: 253 comandos en pm-workspace. Todos los comandos ≤150 líneas, con YAML frontmatter, warm Savia persona (female owl), contexto Spanish.

[0.70.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.69.0...v0.70.0

---

## [0.69.0] — 2026-03-02

Audit Trail & Compliance — Inmutable audit trail de todas las acciones de Savia con exportación para auditorías externas, búsqueda contextual y alertas de anomalías. Era 12 — Team Excellence & Enterprise (4/5).

### Added

- **`/audit-trail`** — Log inmutable de todas acciones: comandos ejecutados, recomendaciones, decisiones, archivos. Append-only. Cumple EU AI Act, ISO 42001, NIST AI RMF.
- **`/audit-export`** — Exporta trail en JSON (SIEM), CSV (análisis), PDF (compliance). Incluye hash SHA-256 para verificación de integridad.
- **`/audit-search`** — Búsqueda contextual por fecha, usuario, acción. NL search soportado. Regex patterns. Timeline visualization. Saved searches.
- **`/audit-alert`** — Alertas automáticas por patrones anómalos: fuera de horario, comandos riesgo alto sin aprobación, volumen inusual, acceso a datos sensibles. Canales: Slack, email, dashboard.

### Changed

- Command count: 245 → 249 (+4 comandos auditoría)

[0.69.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.68.0...v0.69.0

---

## [0.68.0] — 2026-03-02

Accessibility & Inclusive Design — Auditoría WCAG 2.2, correcciones automáticas, reportes de conformidad, monitorización continua.

### Added

- **`/a11y-audit`** — Auditoría exhaustiva de accesibilidad WCAG 2.2 (AA/AAA) con detección de alt text, contraste, navegación por teclado, ARIA, focus management, jerarquía de encabezados
- **`/a11y-fix`** — Correcciones automáticas con preview y verificación; covers alt text, ARIA attributes, focus traps, skip links, color contrast
- **`/a11y-report`** — Reportes multi-formato: ejecutivo (score + gráficos), técnico (detalles + código), legal (VPAT/Section 508); tracking de tendencias
- **`/a11y-monitor`** — Monitorización continua en CI/CD; bloquea deploys con regresiones de accesibilidad; digest semanal

### Changed

- Command count: 245 → 249 (+4 comandos accesibilidad)

[0.68.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.67.0...v0.68.0

---

## [0.67.0] — 2026-03-02

Team Wellbeing & Sustainability — Detección temprana de burnout, equilibrado de carga y ritmo sostenible.

### Added

- **`/burnout-radar`** — Detección de señales tempranas de burnout con mapa de calor por miembro
- **`/workload-balance`** — Equilibrado objetivo de carga respetando especialidades
- **`/sustainable-pace`** — Cálculo de ritmo sostenible basado en histórico y capacidad
- **`/team-sentiment`** — Análisis de sentimiento del equipo con pulse surveys y tendencias

### Enhanced

- **role-workflows.md** — Aggregated wellbeing commands for SM/Flow Facilitator role
- **context-map.md** — Added wellbeing group for Team Excellence domain

### Changed

- Command count: 237 → 241 (+4 wellbeing commands in Era 12)
- Era 12 — Team Excellence & Enterprise (2/5 features)

[0.67.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.66.0...v0.67.0

---

## [0.66.0] — 2026-02-28

Advanced DX Metrics — Deep-work analysis, flow-state protection, developer experience profiling, and prevention-focused feedback loops.

### Added

- **`/dx-core4-survey`** — Adapted survey for Speed, Effectiveness, Quality, Impact dimensions
- **`/flow-protect`** — Detect and protect deep-work sessions; block interruptions; suggest focus blocks
- **`/deep-work-analyze`** — Analyze developer deep-work patterns; measure focus time and context switching
- **`/prevention-metrics`** — Preventive metrics: friction points before they block; suggested workflow improvements

### Changed

- Command count: 241 → 245 (+4 DX metrics commands)

[0.66.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.65.0...v0.66.0

---

## [0.65.0] — 2026-02-28

Multi-Layer Caching — Cache strategy, warm operations, analytics, and selective invalidation for context optimization.

### Added

- **`/cache-strategy`** — Define multi-layer cache policy (system, session, command, query levels)
- **`/cache-warm`** — Predictive pre-warming for next operations based on patterns
- **`/cache-analytics`** — Dashboard of cache hit rates, latency improvements, and cost savings
- **`/cache-invalidate`** — Selective invalidation after configuration changes; audit trail

### Changed

- Command count: 237 → 241 (+4 caching commands)

[0.65.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.64.0...v0.65.0

---

## [0.64.0] — 2026-03-02

Semantic Memory 2.0 — Four new memory intelligence commands for semantic compression, importance scoring, knowledge graphs, and intelligent pruning.

### Added

- **`/memory-compress`** — Semantic compression: reduce engrams by up to 80% while preserving fidelity via entity extraction, event summarization, decision condensation, context deduplication
- **`/memory-importance`** — Importance scoring: rank engrams by composite score (relevance × recency × frequency access). Identify high-value and low-value candidates
- **`/memory-graph`** — Knowledge graph from engrams: build relational map of entities, events, decisions. Query connections, detect isolated memories, generate Mermaid visualization
- **`/memory-prune`** — Intelligent pruning: archive low-importance memories, preserve critical ones. Reversible with restore. Never prunes decision-log entries

### Changed

- Command count: 237 → 241 (+4 memory commands)

[0.64.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.63.0...v0.64.0

---

## [0.63.0] — 2026-03-02

Evolving Playbooks — Four new playbook commands for capturing and evolving repetitive workflows using ACE framework.

### Added

- **`/playbook-create`** — Create evolutionary playbooks for releases, onboarding, audits, deploys
- **`/playbook-reflect`** — Post-execution reflection (ACE Reflector): analyze what worked, failed, improve
- **`/playbook-evolve`** — Evolve playbooks with insights (Generator→Reflector→Curator cycle from ACE)
- **`/playbook-library`** — Shareable library of mature playbooks across projects with effectiveness ratings

### Changed

- Command count: 233 → 237 (+4 playbook commands)

[0.63.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.62.0...v0.63.0

---

## [0.62.0] — 2026-03-02

Intelligent Context Loading — Four new context management commands for optimal token budgeting and lazy loading (Context Engineering 2.0).

### Added

- **`/context-budget`** — Token budget per session with optimization suggestions
- **`/context-defer`** — Deferred loading system (85% token reduction)
- **`/context-profile`** — Context consumption profiling (flame-graph style)
- **`/context-compress`** — Semantic compression (80% reduction target)

### Changed

- Command count: 229 → 233 (+4 context commands)

[0.62.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.61.0...v0.62.0

---

## [0.61.0] — 2026-03-02

Vertical Compliance Extensions — Four new vertical-specific compliance commands for regulated sectors (healthcare, finance, legal, education).

### Added

- **`/vertical-healthcare`** — HIPAA, HL7 FHIR, FDA 21 CFR Part 11
- **`/vertical-finance`** — SOX, Basel III, MiFID II, PCI DSS
- **`/vertical-legal`** — GDPR, eDiscovery, contract lifecycle, legal hold
- **`/vertical-education`** — FERPA, Section 508/WCAG, COPPA, LMS integration

### Changed

- Command count: 225 → 229 (+4 vertical compliance commands)

[0.61.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.60.0...v0.61.0

---

## [0.60.0] — 2026-03-02

Enterprise AI Governance — Four new governance commands based on NIST AI RMF, ISO/IEC 42001, and EU AI Act.

### Added

- **`/governance-policy`** — Define company AI policy, risk classification, approval matrix, audit trail
- **`/governance-audit`** — Compliance audit against policy
- **`/governance-report`** — Executive report mapped to frameworks
- **`/governance-certify`** — Certification checklist and readiness scoring

### Changed

- Command count: 221 → 225 (+4 governance commands)

[0.60.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.59.0...v0.60.0

---

## [0.59.0] — 2026-03-02

AI Adoption Companion — Four new adoption commands for team maturity assessment, personalized learning paths, safe practice environments, and friction tracking.

### Added

- **`/adoption-assess`** — Evaluate team adoption maturity using ADKAR model
- **`/adoption-plan`** — Personalized adoption plan by role with learning paths
- **`/adoption-sandbox`** — Safe practice environment without risks
- **`/adoption-track`** — Adoption metrics and friction point detection

### Changed

- Command count: 217 → 221 (+4 adoption commands)

[0.59.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.58.0...v0.59.0

---

## [0.58.0] — 2026-03-02

AI Safety & Human Oversight — Four new safety commands for supervision levels, confidence transparency, boundary definition, and incident tracking.

### Added

- **`/ai-safety-config`** — Configure supervision levels (inform/recommend/decide/execute)
- **`/ai-confidence`** — Transparency dashboard showing confidence, reasoning, data used
- **`/ai-boundary`** — Define explicit boundary matrix per role
- **`/ai-incident`** — Record and analyze Savia incidents

### Changed

- Command count: 213 → 217 (+4 safety commands)

[0.58.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.57.0...v0.58.0

---

## [0.57.0] — 2026-03-02

Ceremony Intelligence — Four new commands for asynchronous standups, retro pattern analysis, ceremony health metrics, and smart agenda generation.

### Added

- **`/async-standup`** — Asynchronous standup collection and compilation
- **`/retro-patterns`** — Pattern analysis from retrospectives
- **`/ceremony-health`** — Health metrics for ceremonies
- **`/meeting-agenda`** — Intelligent agenda generation

### Changed

- Command count: 209 → 213 (+4 ceremony commands)

[0.57.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.56.0...v0.57.0

---

## [0.56.0] — 2026-03-02

Intelligent Backlog Management — Four new commands for assisted grooming, smart prioritization (RICE/WSJF), outcome tracking, and conflict resolution.

### Added

- **`/backlog-groom`** — Detect obsolete, duplicate items without acceptance criteria
- **`/backlog-prioritize`** — Automatic RICE/WSJF prioritization
- **`/outcome-track`** — Post-release outcome tracking
- **`/stakeholder-align`** — Conflict resolution with objective data

### Changed

- Command count: 205 → 209 (+4 backlog commands)

[0.56.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.55.0...v0.56.0

---

## [0.55.0] — 2026-03-02

OKR & Strategic Alignment — Four new commands for OKR definition, tracking, visualization, and strategic mapping.

### Added

- **`/okr-define`** — Define Objectives and Key Results linked to projects
- **`/okr-track`** — Automatic OKR progress tracking
- **`/okr-align`** — Visualize project→OKR→strategy alignment
- **`/strategy-map`** — Strategic map with initiatives and dependencies

### Changed

- Command count: 201 → 205 (+4 strategy commands)

[0.55.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.54.0...v0.55.0

---

## [0.54.0] — 2026-03-02

Company Profile — Four new commands for enterprise onboarding and configuration.

### Added

- **`/company-setup`** — Conversational onboarding of enterprise profile
- **`/company-edit`** — Edit company profile sections
- **`/company-show`** — Display consolidated profile with gap detection
- **`/company-vertical`** — Detect and configure vertical and regulations

### Changed

- Command count: 197 → 201 (+4 company setup commands)

[0.54.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.53.0...v0.54.0

---

## [0.53.0] — 2026-03-02

Multi-Platform Support — Three new commands for multi-platform integration.

### Added

- **`/jira-connect`** — Connect and sync with Jira Cloud
- **`/github-projects`** — Integration with GitHub Projects v2
- **`/platform-migrate`** — Assisted migration between platforms

### Changed

- **`/linear-sync`** — Rewritten with new format, webhooks, unified metrics

[0.53.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.52.0...v0.53.0

---

## [0.52.0] — 2026-03-02

Integration Hub — Four new commands for MCP server exposure, natural language queries, webhook configuration, and integration status.

### Added

- **`/mcp-server`** — Expose Savia tools as MCP server for other projects
- **`/nl-query`** — Natural language queries without memorizing commands
- **`/webhook-config`** — Configure webhooks for real-time event push
- **`/integration-status`** — Dashboard of all integration health

### Changed

- Command count: 174 → 178 (+4 integration commands)

[0.52.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.51.0...v0.52.0

---

## [0.51.0] — 2026-03-02

AI-Powered Planning — Four new commands for intelligent sprint planning, risk prediction, meeting summarization, and capacity forecasting.

### Added

- **`/sprint-autoplan`** — Intelligent sprint planning from backlog and capacity
- **`/risk-predict`** — Sprint risk prediction with early signals
- **`/meeting-summarize`** — Transcription and action item extraction
- **`/capacity-forecast`** — Medium-term capacity forecasting (3-6 sprints)

### Changed

- Command count: 170 → 174 (+4 planning commands)

[0.51.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.50.0...v0.51.0

---

## [0.50.0] — 2026-03-02

Cross-Project Intelligence — Four new commands for portfolio-level visibility and analysis.

### Added

- **`/portfolio-deps`** — Inter-project dependency graph with bottleneck detection
- **`/backlog-patterns`** — Detect duplicates across projects
- **`/org-metrics`** — Aggregated DORA metrics at organization level
- **`/cross-project-search`** — Unified search across all portfolio projects

### Changed

- Command count: 166 → 170 (+4 cross-project commands)

[0.50.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.49.0...v0.50.0

---

## [0.49.0] — 2026-03-01

Product Owner Analytics — Four new commands providing strategic views for POs.

### Added

- **`/value-stream-map`** — Value stream mapping with bottleneck detection
- **`/feature-impact`** — Feature impact on ROI and engagement
- **`/stakeholder-report`** — Executive report for stakeholders
- **`/release-readiness`** — Release readiness verification

### Changed

- Command count: 162 → 166 (+4 PO commands)

[0.49.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.48.0...v0.49.0

---

## [0.48.0] — 2026-03-01

Tech Lead Intelligence — Four new commands for technology health and team knowledge.

### Added

- **`/tech-radar`** — Technology stack mapping (adopt/trial/hold/retire)
- **`/team-skills-matrix`** — Competency matrix with bus factor calculation
- **`/arch-health`** — Architectural health scoring
- **`/incident-postmortem`** — Blameless postmortem template

### Changed

- Command count: 158 → 162 (+4 tech lead commands)

[0.48.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.47.0...v0.48.0

---

## [0.47.0] — 2026-03-01

Developer Productivity — Four new commands for personal sprint view, deep focus, learning opportunities, and pattern catalog.

### Added

- **`/my-sprint`** — Personal sprint view (private, no comparisons)
- **`/my-focus`** — Deep focus mode with context loading
- **`/my-learning`** — Learning opportunity detection from commits
- **`/code-patterns`** — Living pattern catalog from codebase

### Changed

- Command count: 154 → 158 (+4 developer commands)

[0.47.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.46.0...v0.47.0

---

## [0.46.0] — 2026-03-01

QA and Testing Toolkit — Four new commands for complete testing workflow.

### Added

- **`/qa-dashboard`** — Quality panel with coverage and test metrics
- **`/qa-regression-plan`** — Regression test planning based on changes
- **`/qa-bug-triage`** — Assisted bug triage with duplicate detection
- **`/testplan-generate`** — Test plan generation from specs

### Changed

- Command count: 150 → 154 (+4 QA commands)

[0.46.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.45.0...v0.46.0

---

## [0.45.0] — 2026-03-01

Executive Reports for Leadership — Three new commands for C-level strategic views.

### Added

- **`/ceo-report`** — Multi-project executive report with traffic-light scoring
- **`/ceo-alerts`** — Strategic alert panel for director-level decisions
- **`/portfolio-overview`** — Bird's-eye portfolio view with dependencies

### Changed

- Command count: 147 → 150 (+3 CEO commands)

[0.45.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.44.0...v0.45.0

---

## [0.44.0] — 2026-03-01

Semantic Hub Topology — Agentexecution tracing, cost estimation, and efficiency metrics for subagent operations.

### Added

- **`/hub-audit`** — Topology audit revealing hubs, near-hubs, and dormant rules

### Changed

- Command count: 146 → 147 (+1 hub audit command)

[0.44.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.43.0...v0.44.0

---

## [0.43.0] — 2026-03-01

Context Aging and Verified Positioning — Semantic compression of old decisions using neuroscience-inspired aging.

### Added

- **`/context-age`** — Analyze and compress aged decisions
- **`/context-benchmark`** — Verify optimal information positioning
- **`scripts/context-aging.sh`** — Automation script

### Changed

- Command count: 144 → 146 (+2 context commands)

[0.43.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.42.0...v0.43.0

---

## [0.42.0] — 2026-03-01

Subagent Context Budget System — All 24 agents now have explicit max_context_tokens and output_max_tokens fields.

### Changed

- All 24 agent frontmatter files updated with context budgets (4 tiers)

[0.42.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.41.0...v0.42.0

---

## [0.41.0] — 2026-03-01

Session-Init Compression and CLAUDE.md Pre-compaction — 4-level priority system for session initialization.

### Changed

- **`session-init.sh`** — Rewritten with priority-based array system
- **CLAUDE.md** — Pre-compacted from 154 → 125 lines (36% reduction)

[0.41.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.40.0...v0.41.0

---

## [0.40.0] — 2026-03-01

Role-Adaptive Daily Routines, Project Health Dashboard, and Context Usage Optimization.

### Added

- **`/daily-routine`** — Role-adaptive daily routine
- **`/health-dashboard`** — Unified project health dashboard
- **`/context-optimize`** — Context usage analysis with recommendations
- **`scripts/context-tracker.sh`** — Lightweight context usage tracking

### Changed

- Command count: 141 → 144 (+3 context commands)

[0.40.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.39.0...v0.40.0

---

## [0.39.0] — 2026-03-01

Encrypted Cloud Backup System — AES-256-CBC encryption before cloud upload with auto-rotation.

### Added

- **`/backup`** — 5 subcommands for backup management
- **`scripts/backup.sh`** — Full backup lifecycle automation

### Changed

- Command count: 140 → 141 (+1 backup command)

[0.39.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.38.0...v0.39.0

---

## [0.38.0] — 2026-03-01

Private Review Protocol — Maintainer workflow for reviewing community PRs and issues.

### Added

- **`/review-community`** — 5 subcommands for PR/issue review and release

### Changed

- Command count: 139 → 140 (+1 review command)

[0.38.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.37.0...v0.38.0

---

## [0.37.0] — 2026-03-01

Vertical Detection System — Detect non-software sectors and propose specialized extensions.

### Added

- **`/vertical-propose`** — Detect vertical or receive name and generate extensions

### Changed

- Command count: 138 → 139 (+1 vertical detection command)

[0.37.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.36.0...v0.37.0

---

## [0.36.0] — 2026-03-01

Community & Collaboration System — Privacy-first contribution system with credential validation.

### Added

- **`/contribute`** — Create PRs, propose ideas, report bugs
- **`/feedback`** — Open issues with validation

### Changed

- Command count: 136 → 138 (+2 community commands)

[0.36.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.35.0...v0.36.0

---

## [0.35.0] — 2026-03-01

Savia — User Profiling System and Agent Mode. Introduce Savia identity with fragmented user profiles and agent mode support.

### Added

- **`/profile-setup`** — Savia's conversational onboarding
- **`/profile-edit`** — Edit profile sections
- **`/profile-switch`** — Switch between profiles
- **`/profile-show`** — Display active profile

### Changed

- Command count: 131 → 135 (+4 profile commands)
- ~72 existing commands updated with profile loading

[0.35.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.34.0...v0.35.0

---

## [0.34.0] — 2026-02-28

Performance Audit Intelligence — Static analysis for code performance hotspots.

### Added

- **`/perf-audit`** — Static performance analysis
- **`/perf-fix`** — Test-first optimization
- **`/perf-report`** — Executive performance report

### Changed

- Command count: 129 → 131 (+3 performance commands)

[0.34.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.3...v0.34.0

---

## [0.33.3] — 2026-02-28

Azure DevOps project validation — Automated audit of project configuration.

### Added

- **`/devops-validate`** — Audit Azure DevOps project config

### Changed

- Command count: 128 → 129 (+1 DevOps command)

[0.33.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.2...v0.33.3

---

## [0.33.2] — 2026-02-28

Detection algorithm calibration after real-world testing across regulated sectors.

### Changed

- Detection algorithm: 4 phases → 5 phases
- Confidence thresholds recalibrated

[0.33.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.1...v0.33.2

---

## [0.33.1] — 2026-02-28

Compliance commands improvements after real-world testing.

### Fixed

- Output file naming with date suffix
- Scoring formula documentation
- Dry-run vs actual execution indication

[0.33.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.33.0...v0.33.1

---

## [0.33.0] — 2026-02-28

Regulatory Compliance Intelligence — Automated sector detection and compliance scanning across 12 regulated industries.

### Added

- **`/compliance-scan`** — Automated compliance scanning
- **`/compliance-fix`** — Auto-fix framework for violations
- **`/compliance-report`** — Generate compliance report

### Changed

- Command count: 125 → 128 (+3 compliance commands)

[0.33.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.3...v0.33.0

---

## [0.32.3] — 2026-02-28

Multi-OS emergency mode — Support for Linux, macOS, and Windows.

[0.32.3]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.2...v0.32.3

---

## [0.32.2] — 2026-02-28

Fix Ollama download — Adapted to new tar.zst archive format.

[0.32.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.1...v0.32.2

---

## [0.32.1] — 2026-02-28

Emergency plan — Preventive pre-download of Ollama and LLM for offline installation.

[0.32.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.32.0...v0.32.1

---

## [0.32.0] — 2026-02-28

Emergency mode — Local LLM contingency plan with Ollama setup and offline operations.

### Added

- **`/emergency-mode`** — Manage emergency mode with local LLM

[0.32.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.31.0...v0.32.0

---

## [0.31.0] — 2026-02-28

Architecture intelligence — Pattern detection and recommendations across 16 languages.

### Added

- **`/arch-detect`** — Detect architecture pattern
- **`/arch-suggest`** — Generate improvement suggestions
- **`/arch-recommend`** — Recommend optimal pattern
- **`/arch-fitness`** — Define and execute fitness functions
- **`/arch-compare`** — Compare architecture patterns

[0.31.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.30.0...v0.31.0

---

## [0.30.0] — 2026-02-28

Technical debt intelligence — Automated analysis and prioritization.

### Added

- **`/debt-analyze`** — Automated debt discovery
- **`/debt-prioritize`** — Prioritize by business impact
- **`/debt-budget`** — Propose sprint debt budget

[0.30.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.29.0...v0.30.0

---

## [0.29.0] — 2026-02-28

AI governance and EU AI Act compliance — Model cards and risk assessment.

### Added

- **`/ai-model-card`** — Generate AI model cards
- **`/ai-risk-assessment`** — Risk assessment per EU AI Act
- **`/ai-audit-log`** — Chronological audit log from traces

[0.29.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.28.0...v0.29.0

---

## [0.28.0] — 2026-02-28

Developer Experience metrics — DX Core 4 surveys and automated dashboards.

### Added

- **`/dx-survey`** — Adapted DX Core 4 surveys
- **`/dx-dashboard`** — Automated DX dashboard
- **`/dx-recommendations`** — Friction point analysis

[0.28.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.27.0...v0.28.0

---

## [0.27.0] — 2026-02-28

Agent observability — Execution tracing, cost estimation, and efficiency metrics.

### Added

- **`/agent-trace`** — Dashboard of agent executions
- **`/agent-cost`** — Cost estimation per agent
- **`/agent-efficiency`** — Efficiency analysis

[0.27.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.26.0...v0.27.0

---

## [0.26.0] — 2026-02-28

Predictive analytics and flow metrics — Sprint forecasting with Monte Carlo simulation.

### Added

- **`/sprint-forecast`** — Predict sprint completion
- **`/flow-metrics`** — Value stream dashboard
- **`/velocity-trend`** — Velocity analysis

[0.26.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.25.0...v0.26.0

---

## [0.25.0] — 2026-02-28

Security hardening and community patterns — SAST audit, dependency scanning, and SBOM generation.

### Added

- **`/security-audit`** — SAST analysis against OWASP Top 10
- **`/dependencies-audit`** — Vulnerability scanning
- **`/sbom-generate`** — Generate SBOM
- **`/credential-scan`** — Scan git history for leaked credentials
- **`/epic-plan`** — Multi-sprint epic planning
- **`/worktree-setup`** — Automate git worktree creation

### Changed

- Command count: 96 → 102 (+6 security commands)

[0.25.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.24.0...v0.25.0

---

## [0.24.0] — 2026-02-28

Permissions and CI/CD hardening — Plan-gate hook and CI validation steps.

### Added

- **`/validate-filesize`** — Check file size compliance
- **`/validate-schema`** — Validate JSON schemas

### Changed

- Command count: 94 → 96 (+2 validation commands)

[0.24.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.23.0...v0.24.0

---

## [0.23.0] — 2026-02-28

Automated code review — Pre-commit review hook with SHA256 cache.

### Added

- **`/review-cache-stats`** — Show review cache statistics
- **`/review-cache-clear`** — Clear review cache

### Changed

- Command count: 92 → 94 (+2 review commands)

[0.23.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.22.0...v0.23.0

---

## [0.22.0] — 2026-02-28

SDD workflow enhanced with Agent Teams Lite patterns.

### Added

- **`/spec-explore`** — Pre-spec exploration
- **`/spec-design`** — Technical design phase
- **`/spec-verify`** — Spec compliance matrix

### Changed

- Command count: 89 → 92 (+3 SDD commands)

[0.22.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.21.0...v0.22.0

---

## [0.21.0] — 2026-02-28

Persistent memory system inspired by Engram — JSONL-based memory with deduplication.

### Added

- **`/memory-save`** — Save memory with topic
- **`/memory-search`** — Search memory store
- **`/memory-context`** — Load context from memory

### Changed

- Command count: 86 → 89 (+3 memory commands)

[0.21.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.20.1...v0.21.0

---

## [0.20.1] — 2026-02-27

Fix developer_type format — Revert to hyphen format.

[0.20.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.20.0...v0.20.1

---

## [0.20.0] — 2026-02-27

Context optimization and 150-line discipline enforcement.

### Changed

- 9 skills refactored with progressive disclosure
- 5 agents refactored with companion domain files
- CLAUDE.md compacted from 195 → 130 lines

[0.20.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.19.0...v0.20.0

---

## [0.19.0] — 2026-02-27

Governance hardening — Scope guard hook and parallel session serialization rule.

### Added

- **Scope Guard Hook** for scope creep detection

### Changed

- **`/context-load`** expanded with ADR loading

[0.19.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.18.0...v0.19.0

---

## [0.18.0] — 2026-02-27

Multi-agent coordination — Agent-notes system, TDD gate hook, and ADR support.

### Added

- **`/security-review`** — Pre-implementation security review
- **`/adr-create`** — Create Architecture Decision Records
- **`/agent-notes-archive`** — Archive completed agent-notes

### Changed

- SDD skill workflow expanded with security review and TDD gate

[0.18.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.17.0...v0.18.0

---

## [0.17.0] — 2026-02-27

Advanced agent capabilities and programmatic hooks system.

### Changed

- 23 agents upgraded with advanced frontmatter
- 11 skills updated with context and agent fields
- 7 programmatic hooks added via settings.json

[0.17.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.16.0...v0.17.0

---

## [0.16.0] — 2026-02-27

Intelligent memory system — Path-specific auto-loading and auto memory.

### Added

- **`/memory-sync`** — Consolidate session insights
- **`scripts/setup-memory.sh`** — Initialize memory structure

### Changed

- 21 language files and 3 domain files now have path-specific rules

[0.16.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.15.1...v0.16.0

---

## [0.15.1] — 2026-02-27

Auto-compact post-command — Prevent context saturation.

### Changed

- Auto-compact protocol enforced after every command
- 7 commands freed from context-ux-feedback dependency

[0.15.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.15.0...v0.15.1

---

## [0.15.0] — 2026-02-27

Command naming fix — All commands renamed from colon to hyphen notation.

### Fixed

- All 106 unique command references renamed across 164 files

[0.15.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.14.1...v0.15.0

---

## [0.14.1] — 2026-02-27

Context optimization — Auto-loaded baseline reduced by 79%.

### Changed

- 10 domain rules moved to on-demand loading
- `/help` rewritten with separate setup and catalog modes

[0.14.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.14.0...v0.14.1

---

## [0.14.0] — 2026-02-27

Session persistence — Save/load rituals for persistent "second brain".

### Added

- **`/session-save`** — Capture decisions before clearing
- **`decision-log.md`** — Private cumulative decision register

### Changed

- **`/context-load`** rewritten to load big picture

[0.14.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.2...v0.14.0

---

## [0.13.2] — 2026-02-27

Fix silent failures — Heavy commands now explicitly delegate to subagents.

### Fixed

- **`/project-audit`** silent failure fixed with subagent delegation

[0.13.2]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.1...v0.13.2

---

## [0.13.1] — 2026-02-27

Anti-improvisation — Commands strictly execute only what their spec defines.

### Changed

- **`/help`** rewritten with explicit stack detection

[0.13.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.13.0...v0.13.1

---

## [0.13.0] — 2026-02-27

Context health and operational resilience — Proactive context management.

### Added

- **Context health rule** with output-first pattern and compaction suggestions

### Changed

- Auto-loaded context reduced: 2,109 → 899 lines

[0.13.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.12.0...v0.13.0

---

## [0.12.0] — 2026-02-27

Context optimization — 58% reduction in auto-loaded context.

### Changed

- 8 rules moved from auto-load to on-demand
- Auto-loaded context reduced from 2,109 → 882 lines

[0.12.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.11.0...v0.12.0

---

## [0.11.0] — 2026-02-27

UX Feedback Standards — Consistent visual feedback for all commands.

### Added

- **UX Feedback rule** with mandatory standards for all commands

### Changed

- 6 core commands updated with UX feedback pattern

[0.11.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.10.0...v0.11.0

---

## [0.10.0] — 2026-02-27

Infrastructure and tooling — GitHub Actions and MCP migration guide.

### Added

- **GitHub Actions** PR auto-labeling workflow
- **MCP migration guide** for azdevops-queries functions

[0.10.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.9.0...v0.10.0

---

## [0.9.0] — 2026-02-27

Messaging & Voice Inbox — WhatsApp, Nextcloud Talk, and voice transcription.

### Added

- **`/notify-whatsapp`** — Send WhatsApp notifications
- **`/whatsapp-search`** — Search WhatsApp messages
- **`/notify-nctalk`** — Send Nextcloud Talk notifications
- **`/nctalk-search`** — Search Nextcloud Talk messages
- **`/inbox-check`** — Check and process new messages
- **`/inbox-start`** — Start background inbox monitoring

### Changed

- Command count: 75 → 81 (+6 messaging commands)
- Skills count: 12 → 13 (+voice-inbox)

[0.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.8.0...v0.9.0

---

## [0.8.0] — 2026-02-27

DevOps Extended — Azure DevOps Wiki, Test Plans, and security alerts.

### Added

- **`/wiki-publish`** — Publish to Azure DevOps Wiki
- **`/wiki-sync`** — Bidirectional wiki sync
- **`/testplan-status`** — Test Plans dashboard
- **`/testplan-results`** — Detailed test run results
- **`/security-alerts`** — Security alerts from Azure DevOps

### Changed

- Command count: 70 → 75 (+5 DevOps Extended commands)

[0.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.7.0...v0.8.0

---

## [0.7.0] — 2026-02-27

Project Onboarding Pipeline — 5-phase automated workflow.

### Added

- **`/project-audit`** — Phase 1: deep project audit
- **`/project-release-plan`** — Phase 2: prioritized release plan
- **`/project-assign`** — Phase 3: distribute work across team
- **`/project-roadmap`** — Phase 4: visual roadmap
- **`/project-kickoff`** — Phase 5: compile and notify

### Changed

- Command count: 65 → 70 (+5 onboarding commands)

[0.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.6.0...v0.7.0

---

## [0.6.0] — 2026-02-27

Legacy assessment and release notes — Backlog capture from unstructured sources.

### Added

- **`/legacy-assess`** — Legacy application assessment
- **`/backlog-capture`** — Create PBIs from unstructured input
- **`/sprint-release-notes`** — Auto-generate release notes

### Changed

- Command count: 62 → 65 (+3 legacy & capture commands)

[0.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.5.0...v0.6.0

---

## [0.5.0] — 2026-02-27

Governance foundations — Technical debt tracking and DORA metrics.

### Added

- **`/debt-track`** — Technical debt register
- **`/kpi-dora`** — DORA metrics dashboard
- **`/dependency-map`** — Cross-team/PBI dependency mapping
- **`/retro-actions`** — Retrospective action tracking
- **`/risk-log`** — Risk register

### Changed

- Command count: 57 → 62 (+5 governance commands)

[0.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.4.0...v0.5.0

---

## [0.4.0] — 2026-02-27

Connectors ecosystem and Azure DevOps MCP optimization.

### Added

- **Connector integrations** (12 commands)
- **Azure Pipelines** (5 commands)
- **Azure Repos management** (6 commands)

### Changed

- Command count: 46 → 57 (+11 new commands)
- Skills count: 11 → 12 (+azure-pipelines)

[0.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.0...v0.4.0

---

## [0.3.0] — 2026-02-26

Multi-language support, multi-environment, and infrastructure as code.

### Added

- **16 Language Packs** with conventions, rules, and agents
- **12 new developer agents** for different languages
- **7 new infrastructure commands**
- **File size governance** (max 150 lines per file)

### Changed

- Command count: 24 → 46
- Skills count: 11 → 23
- Agents count: 8 → 35

[0.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.2.0...v0.3.0

---

## [0.2.0] — 2026-02-26

Quality, discovery, and operations expansion.

### Added

- **Product Discovery workflow** (`/pbi-jtbd`, `/pbi-prd`)
- **Quality commands** (`/pr-review`, `/context-load`, `/changelog-update`, `/evaluate-repo`)
- **`product-discovery` skill** with JTBD and PRD templates
- **`test-runner` agent** for post-commit testing

### Changed

- Command count: 19 → 24 (+6)
- Skills count: 7 → 8
- Agents count: 9 → 11

[0.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0...v0.2.0

---

## [0.1.0] — 2026-03-01

Initial public release of PM-Workspace.

### Added

- **Core workspace** with CLAUDE.md and setup guide
- **Sprint management** commands (4)
- **Reporting commands** (6)
- **PBI decomposition commands** (4)
- **Spec-Driven Development** with skills and agents
- **Test project** (sala-reservas)
- **Test suite** (96 tests)
- **Documentation** with methodology

[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.0.0...v0.1.0
