# RESOLVER.md — Intent dispatch table

> **Patrón GBrain RESOLVER.md** (SE-160). Tabla explícita intent → skill/agent que reduce la carga del contexto central y hace el routing editable sin prompt engineering.
>
> **Fuente de verdad**: la sección AUTO se regenera desde `.opencode/skills/*/SKILL.md` y `.opencode/agents/*.md`. La sección OVERRIDE es hand-curated y se preserva entre regeneraciones.

## Cómo se usa

1. Buscas el intent (palabra/frase) en la columna izquierda.
2. Saltas al target indicado: `skill:<nombre>` o `agent:<nombre>`.
3. Si tu intent no aparece, busca en OVERRIDE — sinónimos comunes mapeados a mano.
4. Si sigue sin estar, abre PR contra OVERRIDE añadiéndolo.

**No es un router automático**: es un índice. El frontend (Claude Code, OpenCode) selecciona el target final aplicando su propio matcher; esta tabla es la referencia compartida que evita re-explicar el routing en cada turno.

## OVERRIDE — sinónimos y aliases (hand-curated)

> Esta sección NO se auto-genera. Edita libremente. Mapea términos comunes / sinónimos en español/inglés al target canónico.

| Sinónimo / alias | Target canónico | Notas |
|---|---|---|
| "estado del sprint", "sprint status", "cómo va el sprint" | skill:sprint-management | |
| "informe semanal", "weekly", "weekly report" | skill:weekly-report | |
| "imputaciones", "horas", "timesheet" | skill:time-tracking-report | |
| "facturas", "presupuesto", "coste" | skill:cost-management | |
| "descomponer PBI", "split PBI", "tareas de un PBI" | skill:pbi-decomposition | Antes de descomponer, usar `skill:product-discovery` |
| "PRD", "discovery", "JTBD" | skill:product-discovery | Pre-requisito de pbi-decomposition |
| "buscar comando", "qué comando uso", "router" | skill:smart-routing | Para descubrir entre 559+ comandos |
| "diseñar arquitectura", "architecture", "decisión técnica" | agent:architect | |
| "implementar en C#", ".NET", "EF Core" | agent:dotnet-developer | Requiere Spec SDD aprobada |
| "implementar en Python", "FastAPI", "Django" | agent:python-developer | |
| "revisar código", "code review", "quality gate" | agent:code-reviewer | E1 SIEMPRE humano (Rule 8) |
| "tests faltantes", "cobertura", "test runner" | agent:test-runner | |
| "antes de commit", "pre-commit", "guardian" | agent:commit-guardian | Bloqueante por defecto |
| "tabla de horas", "Excel imputación" | skill:time-tracking-report | |
| "memoria de Savia", "recordar", "consolidar memoria" | skill:savia-memory | |
| "reunión Teams", "transcripción", "acta" | skill:meeting-transcript-extract | Triage al digester correcto post-extract |
| "investigación técnica", "evaluar herramienta nueva" | skill:tech-research-agent | Doble opt-in SPEC-186 |
| "noche autónoma", "overnight", "tareas mientras duermo" | skill:overnight-sprint | Doble opt-in SPEC-186 |
| "auditar seguridad", "red team / blue team" | skill:adversarial-security | Doble opt-in SPEC-186 |
| "Anthropic caído", "failover local", "LocalAI" | skill:emergency-mode | |

## AUTO — generado desde frontmatter

> Esta sección la regenera `bash scripts/resolver-md-generate.sh --apply`. NO editar a mano.

<!-- AUTO_BEGIN — do not edit; regenerate via scripts/resolver-md-generate.sh -->

### Skills (108)

| Intent (skill) | Target | Cuándo usar |
|---|---|---|
| `adversarial-security` | skill:adversarial-security | Usar cuando se necesita auditar la seguridad de un proyecto con pipeline Red Team / Blu... |
| `agent-code-map` | skill:agent-code-map | Usar cuando un agente necesita conocer la arquitectura del proyecto sin leer ficheros c... |
| `agent-file-map` | skill:agent-file-map | Usar cuando se trabaja con ficheros externos al workspace que los agentes deben localizar. |
| `ai-labor-impact` | skill:ai-labor-impact | Usar cuando se analiza el impacto de la IA en el trabajo del equipo o la organización. |
| `android-autonomous-debugger` | skill:android-autonomous-debugger | Usar cuando se depuran o testean apps Android contra dispositivos físicos via USB/ADB. |
| `architecture-intelligence` | skill:architecture-intelligence | Usar cuando se diseña o revisa la arquitectura de un proyecto nuevo o existente. |
| `ast-comprehension` | skill:ast-comprehension | Usar cuando se explora código desconocido y se necesita comprensión estructural sin l... |
| `ast-quality-gate` | skill:ast-quality-gate | Usar cuando se verifica la calidad de código generado por IA antes de merge. |
| `azure-devops-queries` | skill:azure-devops-queries | Usar cuando se necesitan consultas WIQL, actualización de work items o datos de sprint... |
| `azure-pipelines` | skill:azure-pipelines | Usar cuando se gestiona o depura CI/CD con Azure Pipelines. |
| `backlog-git-tracker` | skill:backlog-git-tracker | Usar cuando se capturan o comparan snapshots del backlog para detectar drift. |
| `banking-architecture` | skill:banking-architecture | Usar cuando se diseña o revisa arquitectura para proyectos del sector bancario. |
| `capacity-planning` | skill:capacity-planning | Usar cuando se calcula la capacidad del equipo para un sprint o periodo. |
| `caveman` | skill:caveman | Strips all sugar-coating and marketing. Gives the brutally honest truth in the fewest p... |
| `client-profile-manager` | skill:client-profile-manager | Usar cuando se crean, actualizan o consultan perfiles de cliente en SaviaHub. |
| `code-comprehension-report` | skill:code-comprehension-report | Usar cuando se ha completado una implementación SDD y se necesita documentar el modelo... |
| `code-improvement-loop` | skill:code-improvement-loop | Usar cuando se quiere ejecutar mejora autónoma de código en segundo plano con PRs par... |
| `codebase-map` | skill:codebase-map | Usar cuando se necesita un mapa de dependencias del workspace (comandos→agentes→reg... |
| `codegraph` | skill:codegraph | Usar cuando se necesita indexación AST persistente para navegación de callers/callees... |
| `company-messaging` | skill:company-messaging | Usar cuando se envían mensajes internos cifrados entre miembros de la organización v�... |
| `consensus-validation` | skill:consensus-validation | Usar cuando una decisión técnica o recomendación necesita validación por panel de j... |
| `content-fingerprint` | skill:content-fingerprint | Usar cuando se necesita un identificador corto, deterministico y reproducible derivado ... |
| `context-caching` | skill:context-caching | Usar cuando se optimiza el orden de carga de contexto para maximizar cache hits. |
| `context-interview-conductor` | skill:context-interview-conductor | Usar cuando se necesita recopilar contexto estructurado de un usuario mediante entrevis... |
| `context-optimized-dev` | skill:context-optimized-dev | Usar cuando se desarrolla con presupuesto de contexto limitado. |
| `context-rot-strategy` | skill:context-rot-strategy | Usar cuando una sesión larga se aproxima al límite de contexto y hay que decidir qué... |
| `context-task-classifier` | skill:context-task-classifier | Usar antes de compactar contexto para clasificar la tarea del turno actual. |
| `cost-management` | skill:cost-management | Usar cuando se gestionan timesheets, presupuestos, facturas o forecasting de costes. |
| `dag-scheduling` | skill:dag-scheduling | Usar cuando se orquestan múltiples agentes SDD con dependencias entre ellos. |
| `design-an-interface` | skill:design-an-interface | Design-an-interface skill with N=3 parallel alternatives and architectural vocabulary. ... |
| `developer-experience` | skill:developer-experience | Usar cuando se mide o mejora la experiencia de desarrollo del equipo. |
| `devops-validation` | skill:devops-validation | Usar cuando se conecta un proyecto nuevo a Azure DevOps para validar su configuración ... |
| `diagram-generation` | skill:diagram-generation | Usar cuando se necesita generar diagramas de arquitectura o flujo desde código o infra... |
| `diagram-import` | skill:diagram-import | Usar cuando se importa un diagrama existente para extraer entidades y crear PBIs. |
| `doc-quality-feedback` | skill:doc-quality-feedback | Usar cuando se recopila feedback de calidad de documentación tras usar skills y reglas. |
| `ecosystem-watcher` | skill:ecosystem-watcher | Usar una vez al mes para detectar cambios relevantes en el ecosistema de herramientas e... |
| `emergency-mode` | skill:emergency-mode | Usar cuando la API de Anthropic está caída y se necesita continuar operando con LocalAI. |
| `enterprise-analytics` | skill:enterprise-analytics | Usar cuando se necesitan métricas SPACE, aggregación de portfolio o forecasting empre... |
| `enterprise-onboarding` | skill:enterprise-onboarding | Usar cuando se incorporan múltiples personas a la organización de forma masiva. |
| `epistemic-humility` | skill:epistemic-humility | Usar cuando se detecta riesgo de adulación, cesión sin evidencia, o claim repetido po... |
| `evaluations-framework` | skill:evaluations-framework | Usar cuando se diseñan o ejecutan evaluaciones de calidad de agentes y prompts. |
| `executive-reporting` | skill:executive-reporting | Usar cuando se genera un informe ejecutivo multi-proyecto para dirección. |
| `feasibility-probe` | skill:feasibility-probe | Usar cuando se necesita validar si una spec es técnicamente viable antes de implementa... |
| `governance-enterprise` | skill:governance-enterprise | Usar cuando se audita compliance, se registran decisiones o se certifican procesos ente... |
| `grill-me` | skill:grill-me | Adversarial review that hunts every weakness, assumption, edge case, and missing test. ... |
| `human-code-map` | skill:human-code-map | Usar cuando se incorpora un dev nuevo, se toca un módulo sin mapa, o alguien re-lee el... |
| `knowledge-graph` | skill:knowledge-graph | Usar cuando se construye o consulta el grafo de conocimiento de entidades del proyecto. |
| `legal-compliance` | skill:legal-compliance | Usar cuando se audita compliance legal contra legislación española consolidada. |
| `managed-content` | skill:managed-content | Usar cuando se regeneran secciones auto-generadas en documentos con marcadores de segur... |
| `meeting-transcript-extract` | skill:meeting-transcript-extract | Usar cuando se necesita extraer la transcripción de una reunión Teams desde el browser. |
| `memvid-backup` | skill:memvid-backup | Usar cuando se crea un backup portable de la memoria externa de Savia. |
| `meta-reflection` | skill:meta-reflection | Protocolo de las 4 meta-preguntas para cuestionar el encuadre de una tarea antes de eje... |
| `model-upgrade-audit` | skill:model-upgrade-audit | Usar cuando hay un modelo nuevo disponible y se quiere detectar prompt debt en el works... |
| `mutation-audit` | skill:mutation-audit | Usar cuando se quiere medir la calidad real de los tests mediante mutation testing. |
| `nuclei-scanning` | skill:nuclei-scanning | Usar cuando se escanean vulnerabilidades conocidas (CVEs, misconfigs) con Nuclei. |
| `onboarding-dev` | skill:onboarding-dev | Usar cuando se incorpora un desarrollador nuevo al proyecto y necesita buddy IA. |
| `org-meeting-capture` | skill:org-meeting-capture | Captura de Conocimiento Tácito de Reunión: extrae decisores, acuerdos informales y se... |
| `org-political-landscape` | skill:org-political-landscape | Análisis de Paisaje Político Interno: detecta tensiones, alianzas y centros de poder ... |
| `org-stakeholder-mapper` | skill:org-stakeholder-mapper | Mapeador de Stakeholders y Decisores: extrae roles formales y reales, motivaciones, ali... |
| `orgchart-import` | skill:orgchart-import | Usar cuando se importa un organigrama para extraer la estructura del equipo. |
| `overnight-sprint` | skill:overnight-sprint | Usar cuando se quiere ejecutar tareas de bajo riesgo de forma autónoma durante la noche. |
| `pbi-decomposition` | skill:pbi-decomposition | Usar cuando se descompone un PBI en tasks y se estiman las horas. |
| `pentesting` | skill:pentesting | Usar cuando se ejecuta un pentest contra una aplicación o infraestructura. |
| `performance-audit` | skill:performance-audit | Usar cuando se audita el rendimiento estático de código para detectar hotspots. |
| `personal-vault` | skill:personal-vault | Usar cuando se lee o escribe el repositorio personal del usuario (perfil, preferencias,... |
| `pr-agent-judge` | skill:pr-agent-judge | Usar cuando se añade pr-agent como juez externo en el Code Review Court. |
| `product-discovery` | skill:product-discovery | Usar antes de descomponer PBIs, cuando se necesita análisis JTBD y PRD del producto. |
| `project-update` | skill:project-update | Usar cuando se necesita una actualización integral del proyecto activo desde todas las... |
| `prompt-optimizer` | skill:prompt-optimizer | Usar cuando se optimiza el prompt de un skill o agente para mejorar su efectividad. |
| `rbac-management` | skill:rbac-management | Usar cuando se gestionan roles, permisos o se audita el acceso de usuarios. |
| `reflection-validation` | skill:reflection-validation | Usar cuando una respuesta o decisión importante necesita validación metacognitiva (Sy... |
| `regulatory-compliance` | skill:regulatory-compliance | Usar cuando se valida el cumplimiento de marcos regulatorios sectoriales. |
| `reranker` | skill:reranker | Usar cuando se recibe un top-K ruidoso de búsqueda en memoria y se necesita reordenar ... |
| `resource-references` | skill:resource-references | Usar cuando se necesitan referencias a recursos y plantillas del workspace. |
| `risk-scoring` | skill:risk-scoring | Usar cuando se calcula el riesgo de una tarea para decidir el nivel de revisión requer... |
| `rules-traceability` | skill:rules-traceability | Usar cuando se mapean reglas de negocio a PBIs para trazabilidad completa. |
| `savia-dual` | skill:savia-dual | Usar cuando la inferencia cloud falla, es lenta o está rate-limited y se necesita fail... |
| `savia-flow-practice` | skill:savia-flow-practice | Usar cuando se implementa Savia Flow con dual-track y métricas de flujo en un proyecto. |
| `savia-hub-sync` | skill:savia-hub-sync | Usar cuando se sincroniza el repositorio SaviaHub con el workspace local. |
| `savia-identity` | skill:savia-identity | Usar al inicio de sesión para cargar la identidad completa y las reglas de comportamie... |
| `savia-memory` | skill:savia-memory | Usar cuando se lee, escribe, busca o consolida la memoria persistente entre sesiones de... |
| `savia-school` | skill:savia-school | Usar cuando el workspace se adapta para un entorno educativo con estudiantes menores de... |
| `scaling-operations` | skill:scaling-operations | Usar cuando se analiza el tier de escala de un servicio o se necesitan optimizaciones d... |
| `scheduled-messaging` | skill:scheduled-messaging | Usar cuando se configuran mensajes automáticos programados a plataformas de comunicaci... |
| `skill-evaluation` | skill:skill-evaluation | Usar cuando se necesita seleccionar el skill más apropiado para una tarea dada. |
| `smart-calendar` | skill:smart-calendar | Usar cuando se gestiona la agenda inteligente con sincronización Outlook/Teams. |
| `smart-routing` | skill:smart-routing | Usar cuando se necesita descubrir o enrutar a un comando específico entre los 400+ dis... |
| `sovereignty-auditor` | skill:sovereignty-auditor | Usar cuando se audita el grado de dependencia cognitiva del equipo respecto a herramien... |
| `spec-driven-development` | skill:spec-driven-development | Usar cuando se escribe, valida o implementa una spec ejecutable SDD. |
| `sprint-management` | skill:sprint-management | Usar cuando se consulta el estado del sprint, se actualizan items o se genera el resumen. |
| `tdd-vertical-slices` | skill:tdd-vertical-slices | Test-driven development with vertical-slice red-green-refactor cycles. Use when applyin... |
| `team-coordination` | skill:team-coordination | Usar cuando se coordinan múltiples equipos, se asignan miembros o se detectan bloquean... |
| `team-onboarding` | skill:team-onboarding | Usar cuando se incorpora un nuevo miembro al equipo y se evalúan sus competencias. |
| `tech-research-agent` | skill:tech-research-agent | Usar cuando se necesita investigación técnica autónoma sobre un tema específico. |
| `test-architect` | skill:test-architect | Usar cuando se diseñan o generan tests de alta calidad en cualquier lenguaje. |
| `tier3-probes` | skill:tier3-probes | Usar cuando se valida la viabilidad de herramientas Tier 3 antes de adoptarlas en el wo... |
| `time-tracking-report` | skill:time-tracking-report | Usar cuando se generan informes de imputación de horas en Excel o Word. |
| `topic-cluster` | skill:topic-cluster | Usar cuando se agrupan retros, PBIs o incidentes en topics para detectar patrones trans... |
| `ubiquitous-language` | skill:ubiquitous-language | Usar cuando se necesita extraer o consolidar el glosario de términos de dominio de un ... |
| `understand-anything` | skill:understand-anything | Usar cuando se necesita analizar un codebase con Understand-Anything para generar knowl... |
| `verification-lattice` | skill:verification-lattice | Usar cuando se necesita verificación multi-capa más allá del code review estándar. |
| `voice-inbox` | skill:voice-inbox | Usar cuando se procesan mensajes de voz para transcribirlos y convertirlos en acciones. |
| `web-research` | skill:web-research | Usar cuando se necesita buscar en la web para resolver gaps de contexto (docs, versione... |
| `weekly-report` | skill:weekly-report | Usar cuando se genera el informe semanal de estado del proyecto. |
| `wellbeing-guardian` | skill:wellbeing-guardian | Usar cuando se monitorizan señales de bienestar individual en el equipo. |
| `workspace-integrity` | skill:workspace-integrity | Usar cuando se audita la integridad del workspace (drift, reglas, agentes, baseline). |
| `write-a-skill` | skill:write-a-skill | Guia para crear una nueva skill correctamente en pm-workspace. Usar cuando una tarea se... |
| `zoom-out` | skill:zoom-out | Elevates perspective from trees to forest. Maps architecture, dependencies, and second-... |

### Agents (81)

| Intent (agent) | Target | Cuándo usar |
|---|---|---|
| `architect` | agent:architect | Diseño de arquitectura .NET y decisiones técnicas de alto nivel. Usar PROACTIVELY cua... |
| `architecture-judge` | agent:architecture-judge | Code Review Court judge — boundaries, coupling, layer violations, patterns |
| `archive-digest` | agent:archive-digest | Digestión de formatos de archivo y contenido comprimido via markitdown (SE-172). Sopor... |
| `authority-claim-judge` | agent:authority-claim-judge | Recommendation Tribunal judge — detects credential claims ("soy investigador"). NUNCA... |
| `azure-devops-operator` | agent:azure-devops-operator | Operaciones rápidas en Azure DevOps: consultas WIQL, actualización de work items, ges... |
| `business-analyst` | agent:business-analyst | Análisis de reglas de negocio, descomposición de PBIs, criterios de aceptación y eva... |
| `calibration-judge` | agent:calibration-judge | Truth Tribunal judge — confidence statements match evidence strength |
| `cobol-developer` | agent:cobol-developer | Asistencia en código COBOL/mainframe. IMPORTANTE: La mayoría de tareas COBOL deben re... |
| `code-reviewer` | agent:code-reviewer | Revisión de código .NET como quality gate antes de merge. Usar PROACTIVELY cuando: se... |
| `code-twin-agent` | agent:code-twin-agent | Agente especializado en consultar el Application Code Twin de un proyecto. Usa code-twi... |
| `cognitive-judge` | agent:cognitive-judge | Code Review Court judge — debuggability at 3AM, naming, complexity, logs |
| `coherence-judge` | agent:coherence-judge | Truth Tribunal judge — internal consistency (sums, dates, entities) |
| `coherence-validator` | agent:coherence-validator | Verifies that generated outputs (specs, reports, code) actually match the stated object... |
| `commit-guardian` | agent:commit-guardian | Guardian de commits: verifica que todos los cambios staged cumplen las reglas del works... |
| `completeness-judge` | agent:completeness-judge | Truth Tribunal judge — report covers what its title/abstract promises |
| `compliance-judge` | agent:compliance-judge | Truth Tribunal judge — PII, N1-N4b levels, format rules, confidentiality |
| `concession-judge` | agent:concession-judge | Recommendation Tribunal judge — detects position changes without new evidence (SPEC-192) |
| `confidentiality-auditor` | agent:confidentiality-auditor | Audita cumplimiento de confidencialidad en PRs de pm-workspace (repo publico). Descubre... |
| `configurator` | agent:configurator | Centralizes workspace dispatch decisions: selects skills, agents, rules, and memory que... |
| `correctness-judge` | agent:correctness-judge | Code Review Court judge — logic, tests, edge cases, error paths |
| `court-orchestrator` | agent:court-orchestrator | Convenes the Code Review Court, manages fix cycles, produces .review.crc |
| `criterion-simulation-judge` | agent:criterion-simulation-judge | Criterion Simulation Layer judge — SPEC-194. Executes 4 meta-questions (frame challen... |
| `dev-orchestrator` | agent:dev-orchestrator | Analiza specs y crea planes de implementación con slices, dependencias y presupuestos ... |
| `diagram-architect` | agent:diagram-architect | Architecture diagram specialist. Analyzes code and infrastructure to generate Mermaid d... |
| `dotnet-developer` | agent:dotnet-developer | Implementación de código C#/.NET siguiendo specs SDD aprobadas. Usar PROACTIVELY cuan... |
| `drift-auditor` | agent:drift-auditor | Auditoría de convergencia repo: detecta drift entre docs, config y código. Usar PROAC... |
| `excel-digest` | agent:excel-digest | Digestion de hojas de calculo Excel (XLSX/XLS/CSV) — pipeline de 4 fases. Extrae estr... |
| `expertise-asymmetry-judge` | agent:expertise-asymmetry-judge | Recommendation Tribunal judge — when draft falls in a domain the active user marks as... |
| `factuality-judge` | agent:factuality-judge | Truth Tribunal judge — factual accuracy of claims against verifiable sources |
| `feasibility-probe` | agent:feasibility-probe | Validates spec feasibility by attempting a time-boxed prototype. Produces viability rep... |
| `fiction-framing-judge` | agent:fiction-framing-judge | Recommendation Tribunal judge — detects persona-shift plus content-equivalent framing... |
| `fix-assigner` | agent:fix-assigner | Creates fix tasks from Court findings, assigns to dev agents, triggers re-review |
| `frontend-developer` | agent:frontend-developer | Implementación de código frontend (Angular y React) siguiendo specs SDD aprobadas. Us... |
| `frontend-test-runner` | agent:frontend-test-runner | Post-commit frontend test execution — unit, component, e2e, coverage |
| `go-developer` | agent:go-developer | Implementación de código Go siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: s... |
| `hallucination-fast-judge` | agent:hallucination-fast-judge | Recommendation Tribunal judge — verifies that entities cited in a draft (files, funct... |
| `hallucination-judge` | agent:hallucination-judge | Truth Tribunal judge — detects invented facts via SelfCheck-style consistency |
| `infrastructure-agent` | agent:infrastructure-agent | Agente de gestión de infraestructura cloud. Recibe solicitudes del architect, detecta ... |
| `java-developer` | agent:java-developer | Implementación de código Java/Spring Boot siguiendo specs SDD aprobadas. Usar PROACTI... |
| `legal-compliance` | agent:legal-compliance | Auditoría de compliance legal contra legislación española consolidada (legalize-es).... |
| `meeting-confidentiality-judge` | agent:meeting-confidentiality-judge | Juez de confidencialidad post-extraccion de reuniones. Valida que datos marcados como c... |
| `meeting-digest` | agent:meeting-digest | Digestion de transcripciones de reuniones (VTT, DOCX, TXT). Extrae datos estructurados ... |
| `meeting-risk-analyst` | agent:meeting-risk-analyst | Analisis de riesgos post-digestion de reuniones. Cruza decisiones, compromisos y dinami... |
| `memory-agent` | agent:memory-agent | Gestiona la memoria persistente de pm-workspace via lenguaje natural. |
| `memory-conflict-judge` | agent:memory-conflict-judge | Recommendation Tribunal judge — detects when a draft recommendation contradicts the a... |
| `mobile-developer` | agent:mobile-developer | Implementación de código mobile (Swift/iOS + Kotlin/Android + Flutter) siguiendo spec... |
| `model-upgrade-auditor` | agent:model-upgrade-auditor | Audits agents, skills, and prompts for workarounds that newer models may no longer need... |
| `pdf-digest` | agent:pdf-digest | Digestion de documentos PDF con extraccion de texto e imagenes — pipeline de 4 fases.... |
| `pentester` | agent:pentester | Hacker ético de máximo nivel con pipeline autónomo de 5 fases inspirado en Shannon. ... |
| `php-developer` | agent:php-developer | Implementación de código PHP/Laravel siguiendo specs SDD aprobadas. Usar PROACTIVELY ... |
| `pptx-digest` | agent:pptx-digest | Digestion de presentaciones PowerPoint (PPTX) — pipeline de 4 fases. Extrae texto, no... |
| `pr-agent-judge` | agent:pr-agent-judge | External 5th judge of the Code Review Court — wraps qodo-ai/pr-agent OSS (SPEC-124). ... |
| `python-developer` | agent:python-developer | Implementación de código Python (FastAPI/Django) siguiendo specs SDD aprobadas. Usar ... |
| `recommendation-tribunal-orchestrator` | agent:recommendation-tribunal-orchestrator | Recommendation Tribunal orchestrator — convenes 4 fast judges in parallel, aggregates... |
| `reconciler` | agent:reconciler | Classifies contradictions into 3 buckets: evolution, auto-resolve, conflict-doc. Invoke... |
| `reflection-validator` | agent:reflection-validator | Meta-cognitive validation of responses and decisions (System 2). Use PROACTIVELY when: ... |
| `repetition-truth-judge` | agent:repetition-truth-judge | Recommendation Tribunal judge — detects user claims repeated and assumed true without... |
| `ruby-developer` | agent:ruby-developer | Implementación de código Ruby on Rails siguiendo specs SDD aprobadas. Usar PROACTIVEL... |
| `rule-violation-judge` | agent:rule-violation-judge | Recommendation Tribunal judge — detects when a draft recommendation violates canonica... |
| `rust-developer` | agent:rust-developer | Implementación de código Rust (Axum, Tokio) siguiendo specs SDD aprobadas. Usar PROAC... |
| `sdd-spec-writer` | agent:sdd-spec-writer | Generación y validación de Specs SDD (Spec-Driven Development) como contratos ejecuta... |
| `security-attacker` | agent:security-attacker | Agente Red Team que simula ataques contra el código y la configuración del proyecto. ... |
| `security-auditor` | agent:security-auditor | Agente auditor independiente que evalúa la calidad del análisis Red/Blue Team, verifi... |
| `security-defender` | agent:security-defender | Agente Blue Team que propone correcciones para las vulnerabilidades encontradas por el ... |
| `security-guardian` | agent:security-guardian | Especialista en seguridad, confidencialidad y ciberseguridad. Audita los cambios staged... |
| `security-judge` | agent:security-judge | Code Review Court judge — OWASP, PII, injection, auth, credentials |
| `source-traceability-judge` | agent:source-traceability-judge | Truth Tribunal judge — every claim must have a verifiable @ref citation |
| `spec-judge` | agent:spec-judge | Code Review Court judge — implementation vs approved spec, acceptance criteria |
| `structural-framing-judge` | agent:structural-framing-judge | Recommendation Tribunal judge — detects output with manual/protocol form over CBRN or... |
| `sycophancy-judge` | agent:sycophancy-judge | Recommendation Tribunal judge — detects empty social validation in conversational dra... |
| `tech-writer` | agent:tech-writer | Documentación técnica: README, CHANGELOG, comentarios XML en C#, docs de proyecto. Us... |
| `terraform-developer` | agent:terraform-developer | Implementación de código Terraform (IaC) siguiendo specs SDD aprobadas. CRÍTICO: NUN... |
| `test-architect` | agent:test-architect | Designs and generates the highest quality tests across all 16 language packs and 14 tes... |
| `test-engineer` | agent:test-engineer | Creación y ejecución de tests en proyectos .NET. Usar PROACTIVELY cuando: se escriben... |
| `test-runner` | agent:test-runner | Ejecución de tests y verificación de cobertura post-commit. Ejecuta suite completa de... |
| `truth-tribunal-orchestrator` | agent:truth-tribunal-orchestrator | Truth Tribunal orchestrator — convenes 7 judges, aggregates scores, applies vetos, dr... |
| `typescript-developer` | agent:typescript-developer | Implementación de código TypeScript/Node.js siguiendo specs SDD aprobadas. Usar PROAC... |
| `visual-digest` | agent:visual-digest | Digestión de imágenes con OCR contextual — 5 pasadas. Fotos de pizarras, notas manu... |
| `visual-qa-agent` | agent:visual-qa-agent | Visual QA: screenshot analysis, wireframe comparison, regression detection. Usar PROACT... |
| `web-e2e-tester` | agent:web-e2e-tester | Autonomous E2E testing of web apps against live instances. Use PROACTIVELY when: deploy... |
| `word-digest` | agent:word-digest | Digestion de documentos Word (DOCX) con extraccion de texto, tablas e imagenes — pipe... |

<!-- AUTO_END -->
