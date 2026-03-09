# Catálogo de Subagentes (34)

| Agente | Modelo | Especialidad |
|---|---|---|
| `architect` | Opus 4.6 | Diseño de capas, interfaces, patrones |
| `business-analyst` | Opus 4.6 | Reglas de negocio, criterios de aceptación, evaluación de competencias |
| `sdd-spec-writer` | Opus 4.6 | Specs ejecutables para agentes de código |
| `code-reviewer` | Opus 4.6 | Calidad, seguridad, SOLID |
| `security-guardian` | Opus 4.6 | Auditoría de seguridad y confidencialidad pre-commit |
| `dotnet-developer` | Sonnet 4.6 | Implementación C#/.NET |
| `typescript-developer` | Sonnet 4.6 | Implementación TypeScript/Node.js (NestJS, Express, Prisma) |
| `frontend-developer` | Sonnet 4.6 | Implementación Angular + React |
| `java-developer` | Sonnet 4.6 | Implementación Java/Spring Boot |
| `python-developer` | Sonnet 4.6 | Implementación Python (FastAPI, Django, SQLAlchemy) |
| `go-developer` | Sonnet 4.6 | Implementación Go |
| `rust-developer` | Sonnet 4.6 | Implementación Rust/Axum |
| `php-developer` | Sonnet 4.6 | Implementación PHP/Laravel |
| `mobile-developer` | Sonnet 4.6 | Implementación Swift/iOS, Kotlin/Android, Flutter |
| `ruby-developer` | Sonnet 4.6 | Implementación Ruby on Rails |
| `cobol-developer` | Opus 4.6 | Asistencia COBOL (documentación, copybooks, tests) |
| `terraform-developer` | Sonnet 4.6 | Terraform/IaC (NUNCA ejecuta apply) |
| `infrastructure-agent` | Opus 4.6 | Infra multi-cloud: detectar, crear (tier mínimo), escalar (aprobación humana) |
| `diagram-architect` | Sonnet 4.6 | Análisis de diagramas: consistencia, layering, decomposición Features/PBIs |
| `test-engineer` | Sonnet 4.6 | Testing multi-lenguaje, TestContainers, cobertura |
| `test-runner` | Sonnet 4.6 | Ejecución de tests, cobertura ≥ TEST_COVERAGE_MIN_PERCENT, orquestación de mejora |
| `commit-guardian` | Sonnet 4.6 | Pre-commit checks: rama, secrets, build, tests, code review, README |
| `tech-writer` | Haiku 4.5 | README, CHANGELOG, XML docs |
| `azure-devops-operator` | Haiku 4.5 | WIQL, work items, sprint, capacity |
| `drift-auditor` | Opus 4.6 | Auditoría de convergencia repo: detecta drift entre docs, config y código |
| `reflection-validator` | Opus 4.6 | Validación meta-cognitiva (System 2): supuestos, cadena causal, brechas |
| `coherence-validator` | Sonnet 4.6 | Coherencia output↔objetivo: cobertura, consistencia, completitud |
| `frontend-test-runner` | Sonnet 4.6 | Tests frontend: E2E, componentes, accesibilidad |
| `security-attacker` | Sonnet 4.6 | Red Team: OWASP Top 10, CWE Top 25, dependency audit |
| `security-defender` | Sonnet 4.6 | Blue Team: patches, hardening, NIST/CIS |
| `security-auditor` | Sonnet 4.6 | Auditor independiente: evaluación, score 0-100, gap analysis |
| `pentester` | Opus 4.6 | Pentesting dinámico: pipeline 5 fases (recon → vuln-analysis 5∥ → exploitation proof-based → report). Política "no exploit, no report" |
| `visual-qa-agent` | Sonnet 4.6 | Visual QA: screenshot analysis, wireframe comparison, regression detection |
| `dev-orchestrator` | Sonnet 4.6 | Planificación de slices: análisis de specs, dependencias, presupuestos de contexto |

## Flujos

- **SDD**: `business-analyst` → `architect` → `sdd-spec-writer` → `{lang}-developer` ‖ `test-engineer` → `code-reviewer`
- **Infra**: `architect` → `infrastructure-agent` → (detectar → crear tier mínimo → propuesta) → humano aprueba → apply
- **Pre-commit**: `commit-guardian` (10 checks: rama, security, build, tests, format, code review, README, CLAUDE.md, atomicidad, mensaje)
- **Diagramas**: `diagram-architect` → analizar consistencia → validar reglas negocio → proponer decomposición
- **Post-commit**: `test-runner` (tests completos + cobertura ≥ `TEST_COVERAGE_MIN_PERCENT`)
- **Consenso**: `reflection-validator` + `code-reviewer` + `business-analyst` → panel 3 jueces → score ponderado → veredicto
- **Equality Shield** (Era 26): `/bias-check` audita sesgos contrafácticos en asignaciones y comunicaciones. Integración transversal: antes de `/pbi-assign`, `/sprint-review`, `/sprint-retro`, `/report-executive`.
- **Adversarial Security** (Era 47): `security-attacker` → `security-defender` → `security-auditor` → informe con score 0-100. Pipeline: `/security-pipeline`. Para testing dinámico: `pentester` (5 fases, queue-driven, proof-based) → `security-defender` → `security-auditor` → `pentester` (re-test).
- **Visual QA** (Era 50): `visual-qa-agent` analiza screenshots contra wireframes/mockups. Score 0-100. Pipeline: `/visual-qa` → `/wireframe-check` → `/visual-regression`.
- **Dev Session** (Era 52): `dev-orchestrator` planifica slices → `{lang}-developer` implementa → `test-engineer` + `coherence-validator` validan → `code-reviewer` revisa. Pipeline: `/spec-slice` → `/dev-session start|next|review`.

El agente developer se selecciona según el Language Pack del proyecto.

## Transversales (Cross-Cutting Concerns)

- **Equality Shield** — Auditoría contrafactual de sesgos (vocacional, tonal, emocional, experiencia, liderazgo, comunicación). Regla obligatoria en asignaciones y evaluaciones. Ver `equality-shield.md`.
