---
globs: [".claude/agents/**"]
---

# Assignment Matrix — Task Type → Agent Routing

> Tabla pre-computada para asignación directa sin búsqueda en catálogo.

---

## Matriz Principal

| Tipo de tarea | Agente primario | Backup | QA |
|---|---|---|---|
| API REST (.NET) | dotnet-developer | architect | test-runner |
| API REST (Java) | java-developer | architect | test-runner |
| API REST (Python) | python-developer | architect | test-runner |
| API REST (Go) | go-developer | architect | test-runner |
| API REST (Rust) | rust-developer | architect | test-runner |
| API REST (PHP) | php-developer | architect | test-runner |
| API REST (Ruby) | ruby-developer | architect | test-runner |
| API REST (TypeScript) | typescript-developer | architect | test-runner |
| UI Angular | frontend-developer | typescript-developer | frontend-test-runner |
| UI React | frontend-developer | typescript-developer | frontend-test-runner |
| Mobile iOS | mobile-developer | architect | test-engineer |
| Mobile Android | mobile-developer | architect | test-engineer |
| Mobile Flutter | mobile-developer | architect | test-engineer |
| COBOL maintenance | cobol-developer | — | — |
| VB.NET migration | dotnet-developer | architect | test-runner |
| Spec técnica | sdd-spec-writer | architect | business-analyst |
| Análisis de negocio | business-analyst | sdd-spec-writer | — |
| Diseño arquitectura | architect | — | reflection-validator |
| DB migration (.NET) | dotnet-developer | architect | test-runner |
| DB migration (Java) | java-developer | architect | test-runner |
| DB migration (Python) | python-developer | architect | test-runner |
| Infra/IaC (Terraform) | terraform-developer | infrastructure-agent | architect |
| Infra cloud (manual) | infrastructure-agent | architect | — |
| Security scan (estático) | security-attacker | security-guardian | security-auditor |
| Security scan (dinámico) | pentester | security-defender | security-auditor |
| Security fix | security-defender | dotnet-developer* | security-auditor |
| PR review | code-reviewer | security-guardian | — |
| Pre-commit checks | commit-guardian | — | — |
| Tests unitarios | test-engineer | dotnet-developer* | test-runner |
| Tests E2E/integración | test-engineer | frontend-test-runner | test-runner |
| Tests frontend | frontend-test-runner | test-engineer | — |
| Documentación | tech-writer | — | — |
| Diagramas | diagram-architect | — | — |
| Visual QA | visual-qa-agent | frontend-test-runner | — |
| Azure DevOps ops | azure-devops-operator | — | — |
| Dev session slicing | dev-orchestrator | architect | — |
| Drift audit | drift-auditor | architect | — |
| Consensus validation | reflection-validator | code-reviewer | business-analyst |
| Coherence check | coherence-validator | reflection-validator | — |
| Legal compliance audit | legal-compliance | business-analyst | — |

*El backup para security-fix y tests depende del lenguaje del proyecto.

## Reglas de Selección

1. **Language Pack primero**: Si el proyecto tiene Language Pack detectado, usar el developer de ese lenguaje
2. **Backup solo si primario falla**: No invocar backup preventivamente
3. **QA siempre tras implementación**: Nunca saltarse el agente QA en flujo SDD
4. **Sin agente → humano**: Si no hay agente para el tipo de tarea, escalar

## Selección por Language Pack

| Language Pack | Developer | Test Runner |
|---|---|---|
| C#/.NET | dotnet-developer | test-runner |
| TypeScript/Node.js | typescript-developer | test-runner |
| Angular/React | frontend-developer | frontend-test-runner |
| Java/Spring | java-developer | test-runner |
| Python | python-developer | test-runner |
| Go | go-developer | test-runner |
| Rust | rust-developer | test-runner |
| PHP/Laravel | php-developer | test-runner |
| Swift/Kotlin/Flutter | mobile-developer | test-engineer |
| Ruby/Rails | ruby-developer | test-runner |
| Terraform | terraform-developer | — |
| COBOL | cobol-developer | — |

## Integración

- `/pbi-assign` usa esta matriz para sugerir asignaciones
- `dev-orchestrator` consulta para routing de slices
- `commit-guardian` delega correcciones al agente primario del Language Pack
