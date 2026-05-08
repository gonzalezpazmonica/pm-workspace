# AGENTS.md

> Auto-generated from `.opencode/agents/*.md`. **Do not edit by hand.**
> Source of truth: `docs/rules/domain/agents-md-source-of-truth.md` (SE-078).

## How to use

This file is the cross-frontend mirror of Savia's agent registry. Claude Code
reads `.opencode/agents/*.md` directly; OpenCode v1.14, Codex, Cursor and other
modern frontends pick up this `AGENTS.md` as freeform context. The source of
truth is `.opencode/agents/*.md`; this index is regenerated automatically by
the Stop hook `agents-md-auto-regenerate.sh` whenever an agent file changes.

## Agents

| Name | Model | Permission | Tools | Description |
|---|---|---|---|---|
| architect | heavy | L1 | Read,Glob,Grep,Bash | Diseño de arquitectura .NET y decisiones técnicas de alto nivel. Usar PROACTIVELY cuando: se diseña una nueva feature... |
| architecture-judge | mid | L1 | — | Code Review Court judge — boundaries, coupling, layer violations, patterns |
| azure-devops-operator | fast | L1 | Bash,Read | Operaciones rápidas en Azure DevOps: consultas WIQL, actualización de work items, gestión de sprint, capacidades del ... |
| business-analyst | heavy | L1 | Read,Glob,Grep,Bash | Análisis de reglas de negocio, descomposición de PBIs, criterios de aceptación y evaluación de competencias del equip... |
| calibration-judge | mid | L1 | — | Truth Tribunal judge — confidence statements match evidence strength |
| cobol-developer | heavy | L3 | Read,Write,Edit,Bash,Glob,Grep | Asistencia en código COBOL/mainframe. IMPORTANTE: La mayoría de tareas COBOL deben realizarlas humanos expertos en le... |
| code-reviewer | heavy | L1 | Read,Glob,Grep,Bash | Revisión de código .NET como quality gate antes de merge. Usar PROACTIVELY cuando: se completa una implementación y n... |
| cognitive-judge | mid | L1 | — | Code Review Court judge — debuggability at 3AM, naming, complexity, logs |
| coherence-judge | mid | L1 | — | Truth Tribunal judge — internal consistency (sums, dates, entities) |
| coherence-validator | mid | L0 | Read,Glob,Grep | Verifies that generated outputs (specs, reports, code) actually match the stated objective. Use PROACTIVELY post-SDD,... |
| commit-guardian | mid | L4 | Bash,Read,Glob,Grep,Task | Guardian de commits: verifica que todos los cambios staged cumplen las reglas del workspace ANTES de hacer el commit.... |
| completeness-judge | mid | L1 | — | Truth Tribunal judge — report covers what its title/abstract promises |
| compliance-judge | heavy | L1 | — | Truth Tribunal judge — PII, N1-N4b levels, format rules, confidentiality |
| confidentiality-auditor | heavy | L1 | — | Audita cumplimiento de confidencialidad en PRs de pm-workspace (repo publico). Descubre dinamicamente datos sensibles... |
| correctness-judge | mid | L1 | — | Code Review Court judge — logic, tests, edge cases, error paths |
| court-orchestrator | heavy | L4 | — | Convenes the Code Review Court, manages fix cycles, produces .review.crc |
| dev-orchestrator | mid | L4 | — | Analiza specs y crea planes de implementación con slices, dependencias y presupuestos de contexto |
| diagram-architect | mid | L1 | Read,Glob,Grep,Bash,Write,Edit | Architecture diagram specialist. Analyzes code and infrastructure to generate Mermaid diagrams, validates business ru... |
| dotnet-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código C#/.NET siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: se implementa una feature en... |
| drift-auditor | heavy | L1 | — | Auditoría de convergencia repo: detecta drift entre docs, config y código. Usar PROACTIVELY tras cambios grandes o al... |
| excel-digest | heavy | L2 | — | Digestion de hojas de calculo Excel (XLSX/XLS/CSV) — pipeline de 4 fases. Extrae estructura, formulas, patrones de da... |
| expertise-asymmetry-judge | mid | L1 | — | Recommendation Tribunal judge — when draft falls in a domain the active user marks as `audit_level: blind`, force a r... |
| factuality-judge | heavy | L1 | — | Truth Tribunal judge — factual accuracy of claims against verifiable sources |
| feasibility-probe | mid | L3 | — | Validates spec feasibility by attempting a time-boxed prototype. Produces viability report with score, blocking secti... |
| fix-assigner | mid | L2 | — | Creates fix tasks from Court findings, assigns to dev agents, triggers re-review |
| frontend-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código frontend (Angular y React) siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: se implem... |
| frontend-test-runner | mid | L4 | — | Post-commit frontend test execution — unit, component, e2e, coverage |
| go-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código Go siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: se implementa una feature en Go (... |
| hallucination-fast-judge | fast | L1 | — | Recommendation Tribunal judge — verifies that entities cited in a draft (files, functions, flags, libs, paths, comman... |
| hallucination-judge | heavy | L1 | — | Truth Tribunal judge — detects invented facts via SelfCheck-style consistency |
| infrastructure-agent | heavy | L4 | Read,Write,Edit,Bash,Glob,Grep | Agente de gestión de infraestructura cloud. Recibe solicitudes del architect, detecta infraestructura existente, crea... |
| java-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código Java/Spring Boot siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: se implementa una f... |
| legal-compliance | heavy | L2 | Read,Glob,Grep,Bash,Write | Auditoría de compliance legal contra legislación española consolidada (legalize-es). Usar PROACTIVELY cuando: se crea... |
| meeting-confidentiality-judge | heavy | L1 | Read,Grep | Juez de confidencialidad post-extraccion de reuniones. Valida que datos marcados como confidenciales NO se filtren a ... |
| meeting-digest | mid | L2 | Read,Glob,Grep,Task,Write,Edit | Digestion de transcripciones de reuniones (VTT, DOCX, TXT). Extrae datos estructurados de personas, contexto de negoc... |
| meeting-risk-analyst | heavy | L1 | Read,Glob,Grep | Analisis de riesgos post-digestion de reuniones. Cruza decisiones, compromisos y dinamicas extraidas de una transcrip... |
| memory-agent | fast | L2 | — | Gestiona la memoria persistente de pm-workspace via lenguaje natural. |
| memory-conflict-judge | mid | L1 | — | Recommendation Tribunal judge — detects when a draft recommendation contradicts the active user's auto-memory (feedba... |
| mobile-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código mobile (Swift/iOS + Kotlin/Android + Flutter) siguiendo specs SDD aprobadas. Usar PROACTIVEL... |
| model-upgrade-auditor | heavy | L1 | — | Audits agents, skills, and prompts for workarounds that newer models may no longer need. Proposes simplifications wit... |
| pdf-digest | heavy | L2 | — | Digestion de documentos PDF con extraccion de texto e imagenes — pipeline de 4 fases. Documentos tecnicos, propuestas... |
| pentester | heavy | L3 | Bash,Read,Write,Glob,Grep | Hacker ético de máximo nivel con pipeline autónomo de 5 fases inspirado en Shannon. Ejecuta pentests dinámicos contra... |
| php-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código PHP/Laravel siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: se implementa una featur... |
| pptx-digest | heavy | L2 | — | Digestion de presentaciones PowerPoint (PPTX) — pipeline de 4 fases. Extrae texto, notas del presentador, imagenes, d... |
| pr-agent-judge | mid | L1 | — | External 5th judge of the Code Review Court — wraps qodo-ai/pr-agent OSS (SPEC-124). Opt-in via COURT_INCLUDE_PR_AGEN... |
| python-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código Python (FastAPI/Django) siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: se implement... |
| recommendation-tribunal-orchestrator | mid | L2 | — | Recommendation Tribunal orchestrator — convenes 4 fast judges in parallel, aggregates scores, applies vetos, mutates ... |
| reflection-validator | heavy | L0 | Read,Glob,Grep | Meta-cognitive validation of responses and decisions (System 2). Use PROACTIVELY when: evaluating a response to a com... |
| ruby-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código Ruby on Rails siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: se implementa una feat... |
| rule-violation-judge | mid | L1 | — | Recommendation Tribunal judge — detects when a draft recommendation violates canonical rules (CLAUDE.md, autonomous-s... |
| rust-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código Rust (Axum, Tokio) siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: se implementa una... |
| sdd-spec-writer | heavy | L2 | Read,Write,Edit,Glob,Grep,Bash | Generación y validación de Specs SDD (Spec-Driven Development) como contratos ejecutables. Usar PROACTIVELY cuando: s... |
| security-attacker | mid | L3 | Bash,Read,Glob,Grep | Agente Red Team que simula ataques contra el código y la configuración del proyecto. Busca vulnerabilidades, misconfi... |
| security-auditor | mid | L1 | Bash,Read,Glob,Grep | Agente auditor independiente que evalúa la calidad del análisis Red/Blue Team, verifica que las correcciones son adec... |
| security-defender | mid | L3 | Bash,Read,Write,Glob,Grep | Agente Blue Team que propone correcciones para las vulnerabilidades encontradas por el attacker. Genera patches, conf... |
| security-guardian | heavy | L4 | Bash,Read,Glob,Grep | Especialista en seguridad, confidencialidad y ciberseguridad. Audita los cambios staged ANTES de cualquier commit par... |
| security-judge | mid | L1 | — | Code Review Court judge — OWASP, PII, injection, auth, credentials |
| source-traceability-judge | mid | L1 | — | Truth Tribunal judge — every claim must have a verifiable @ref citation |
| spec-judge | mid | L1 | — | Code Review Court judge — implementation vs approved spec, acceptance criteria |
| tech-writer | fast | L2 | Read,Write,Edit,Glob,Bash | Documentación técnica: README, CHANGELOG, comentarios XML en C#, docs de proyecto. Usar PROACTIVELY cuando: se actual... |
| terraform-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código Terraform (IaC) siguiendo specs SDD aprobadas. CRÍTICO: NUNCA ejecutar terraform apply autom... |
| test-architect | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Designs and generates the highest quality tests across all 16 language packs and 14 test types. Use PROACTIVELY when:... |
| test-engineer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Creación y ejecución de tests en proyectos .NET. Usar PROACTIVELY cuando: se escriben tests unitarios o de integració... |
| test-runner | mid | L4 | Bash,Read,Glob,Grep,Task | Ejecución de tests y verificación de cobertura post-commit. Ejecuta suite completa de tests, valida que todos pasan, ... |
| truth-tribunal-orchestrator | heavy | L2 | — | Truth Tribunal orchestrator — convenes 7 judges, aggregates scores, applies vetos, drives iteration |
| typescript-developer | mid | L3 | Read,Write,Edit,Bash,Glob,Grep | Implementación de código TypeScript/Node.js siguiendo specs SDD aprobadas. Usar PROACTIVELY cuando: se implementa una... |
| visual-digest | heavy | L2 | — | Digestión de imágenes con OCR contextual — 5 pasadas. Fotos de pizarras, notas manuscritas, diagramas en papel, captu... |
| visual-qa-agent | mid | L1 | — | Visual QA: screenshot analysis, wireframe comparison, regression detection. Usar PROACTIVELY cuando se detectan cambi... |
| web-e2e-tester | mid | L3 | — | Autonomous E2E testing of web apps against live instances. Use PROACTIVELY when: deploying savia-web, after UI change... |
| word-digest | heavy | L2 | Read,Write,Edit,Bash,Glob,Grep,Task | Digestion de documentos Word (DOCX) con extraccion de texto, tablas e imagenes — pipeline de 4 fases. Actas, propuest... |