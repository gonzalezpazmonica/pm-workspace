# Catálogo de Subagentes (24)

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

## Flujos

- **SDD**: `business-analyst` → `architect` → `sdd-spec-writer` → `{lang}-developer` ‖ `test-engineer` → `code-reviewer`
- **Infra**: `architect` → `infrastructure-agent` → (detectar → crear tier mínimo → propuesta) → humano aprueba → apply
- **Pre-commit**: `commit-guardian` (10 checks: rama, security, build, tests, format, code review, README, CLAUDE.md, atomicidad, mensaje)
- **Diagramas**: `diagram-architect` → analizar consistencia → validar reglas negocio → proponer decomposición
- **Post-commit**: `test-runner` (tests completos + cobertura ≥ `TEST_COVERAGE_MIN_PERCENT`)

El agente developer se selecciona según el Language Pack del proyecto.
