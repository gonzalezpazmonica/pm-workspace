# Glosario: Términos de Savia Flow

**Autor:** la usuaria González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0

---

## A

### AI Product Manager (AI PM)
Rol evolucionado de Product Owner. Responsable de descubrir outcomes (no features), escribir especificaciones ejecutables, definir success metrics, y priorizar backlog. Usa herramientas de IA para exploración rápida.

### AI QA Agent
Agente especializado en controles de calidad automatizados. Ejemplos: Permission Checker, SQL Injection Detector, CORS Validator. Ejecutan en quality gates sin intervención humana.

### Acceptance Criteria
Checklist de requisitos que deben cumplirse para que una feature sea considerada "completa". En Savia Flow, integrados en Definition of Done.

### Autonomous Quality Gate
Sistema de validación automática que ejecuta sin intervención humana. Proporciona feedback inmediato sobre calidad del código. Escalas: Lint → Tests → Integration → Security → Human Review.

---

## B

### Baseline
Valor actual de una métrica antes de cambios. Ejemplo: "Baseline de conversión es 3.2%". Usado para medir improvement después de feature deployment.

### Backlog
Lista priorizada de features/outcomes espera­ndo ser construidos. En Savia Flow, alimentado continuamente por AI PMs en exploration track.

### Build Start Date
Momento cuando spec es 100% lista y Pro Builder comienza arquitectura y codificación. Marca el inicio del cycle time.

### BMAD Method
"Beyond Measure & Design" - Metodología de investigación que influenció Savia Flow en aspecto de outcomese measurement.

---

## C

### Canary Deployment
Estrategia de despliegue donde feature se distribuye gradualmente: 5% → 25% → 50% → 100% de usuarios. Minimiza risk de breaking changes.

### CFR
Change Failure Rate. Porcentaje de deployments que resultan en incident, rollback, o hotfix. Métrica DORA, target <5%.

### CI/CD
Continuous Integration / Continuous Deployment. Pipeline automático que testa código, ejecuta gates, y deploya a producción.

### Cycle Time
Días desde que especificación está ready hasta que está deployed en producción. NO incluye exploration o spec writing time. Métrica primaria de Savia Flow.

---

## D

### Daily Standup
Ceremonia Scrum de 15 minutos donde equipo reporta progreso. En Savia Flow, eliminada en favor de async metrics dashboard.

### Definition of Done (DoD)
Checklist de requisitos que indican que una feature está completamente terminada. Incluye tests, performance, accessibility, documentation.

### Deployment
Acción de llevar código de staging a producción donde usuarios pueden acceder.

### Deployment Frequency
Métrica DORA. Cuántas veces por día/semana se deploya. Target para elite: 5+ veces por día.

### Dual-Track Development
Patrón de Savia Flow donde exploration (descubrir qué construir) y production (construir) suceden en paralelo. Exploration alimenta producción.

---

## E

### Exploration Track
En dual-track development, el stream de trabajo donde AI PMs descubren outcomes, escriben specs, y validan con usuarios. Timeline: 2-5 días.

### Execution Spec
Especificación ejecutable que incluye outcome, success metrics, functional spec, technical spec, y DoD. Guía completa para implementación.

---

## F

### Flow Facilitator
Rol evolucionado de Scrum Master. Responsable de optimizar flujo de trabajo, remover blockers, interpretar metrics, y coach al equipo. NO ejecuta ceremonias rígidas.

### Flow Metrics
Métricas DORA-based: Cycle Time, Lead Time, Throughput, CFR. Miden flujo real de trabajo, no esfuerzo percibido.

---

## G

### Gate
Validación automática de código. Ejemplos: Lint gate (syntax), test gate (coverage), security gate (SAST), performance gate.

### Gameable (Métrica)
Métrica que puede ser inflada sin crear valor real. Ejemplo: velocity (puntos) es gameable; cycle time no es.

---

## H

### Hotfix
Fix rápido de bug encontrado en producción. Cuenta como part of Change Failure Rate.

---

## I

### Incident
Momento cuando feature rota producción y usuarios experimentan problema. Requiere rollback o inmediato fix.

---

## J

### Jira
Herramienta de gestión de proyectos. Usada a menudo en Savia Flow para tracking de work items, aunque specs viven en GitHub/Notion.

---

## K

### KPI
Key Performance Indicator. Métrica de éxito específica. Ejemplo: "Conversion rate debe mejorar 8%".

---

## L

### Lead Time
Días desde que idea es propuesta hasta que está deployed. Métrica DORA. Incluye exploration + spec + build + gates + deployment.

### Linting
Automated code quality checks (syntax, style, obvious errors). Ejecuta en Level 1 gate.

### Linear
Herramienta moderna de gestión de proyectos (alternativa a Jira). Más lightweight, popular en startups.

---

## M

### Mean Time to Recovery (MTTR)
Cuánto tarda en fixear un broken deploy. Target: <30 minutos.

### Metrics Dashboard
Interfaz donde team ve daily metrics (cycle time, throughput, CFR, WIP). En Savia Flow, visible a todo el team.

### Mutation Testing
Técnica de testing donde code es mutado intencionalmente para verificar que tests lo detectan. Mide test quality, no solo coverage.

---

## N

### n+1 Query Problem
Problema de rendimiento donde código ejecuta N queries en loop (N+1 total), en lugar de 1 query eficiente.

---

## O

### Outcome
Resultado deseado que resuelve un problema de usuario. Diferente de "feature". Ejemplo: "Reducir bounce rate en signup 20%".

### Outcome-Driven
Enfoque de product development donde todo se organiza alrededor de outcomes medibles, no features.

---

## P

### Performance Gate
Validación automática donde código es comparado contra baseline de performance. Flag si >10% regression.

### Pro Builder
Rol evolucionado de Developer. Orquestra IA en código generation, hace code review, mantiene arquitectura. NO solo escribe código.

### Prompt Engineering
Arte de escribir instrucciones claras para IA. Ejemplo: "Generate Express.js API for notifications with pagination" es mejor prompt que "Build API".

### Pull Request (PR)
Cambios de código propuestos para review antes de merge en main branch.

---

## Q

### Quality Architect
Rol responsable de diseño de puertas de calidad, estrategia de testing, y supervisa agentes de IA en gates.

### Quality Gate
Sistema de validaciones automatizadas. Niveles: Lint → Tests → Integration → Security → Human Review.

---

## R

### Rework
Código que fue escrito, pero requiere cambios significativas (>20% reescritura). Métrica de Savia Flow.

### Retrospective (Retro)
Ceremonia donde team reflexiona sobre cómo trabajó. En Savia Flow, monthly en lugar de bisemanal.

### Rollback
Acción de revertir un deployment a versión previa cuando issues son detectadas.

### ROI
Return on Investment. En contexto de Savia Flow adoption, expected ROI es 1600%+ en 6 meses.

---

## S

### SAST
Static Application Security Testing. Herramienta que analiza código para vulnerabilidades de seguridad (SQL injection, XSS, etc.).

### Shape Up
Metodología de Basecamp que influenció Savia Flow, especialmente en uso de especificaciones y ciclos realistas.

### SDD (Spec-Driven Development)
Patrón donde especificaciones ejecutables guían el desarrollo, en lugar de user stories.

### Scrum
Metodología ágil tradicional de 20+ años. Usa sprints fijos, story points, burndown charts. Savia Flow es su evolución.

### Spec
Abreviación de "Especificación ejecutable". Contiene outcome, success metrics, functional details, technical requirements, DoD.

### Spec-Driven Development
Ver SDD.

### Sprint
Contenedor de tiempo fijo (usualmente 2 semanas) en Scrum. Eliminado en Savia Flow en favor de flujo continuo.

---

## T

### Throughput
Métrica DORA. Número de features completadas (deployed) por unidad de tiempo. Target: 8-12 features/semana.

### TypeScript
Lenguaje de programación que extiende JavaScript con tipos estáticos. Ayuda a prevenir bugs.

---

## U

### Uptime
Porcentaje de tiempo que sistema está disponible y funcional. Target: 99.9%+ en SaaS, 99.99%+ en crítico.

---

## V

### Velocity
Métrica Scrum: puntos completados por sprint. En Savia Flow, reemplazada por flow metrics (cycle time, throughput).

---

## W

### Whitepaper
Documento comprensivo que explica filosofía y práctica detrás de Savia Flow. Este es el documento principal de research.

### WIP (Work In Progress)
Límite de cuántas features pueden estar simultaneamente "en construcción". En Savia Flow, típicamente 3-5 items máximo.

---

## X

### XSS (Cross-Site Scripting)
Vulnerabilidad de seguridad donde attacker inyecta código JavaScript malicioso. Detectada por SAST gates.

---

## Y

### (No términos con Y específicos a Savia Flow)

---

## Z

### (No términos con Z específicos a Savia Flow)

---

## Acrónimos

| Acrónimo | Significado |
|----------|------------|
| AI PM | AI Product Manager |
| CFR | Change Failure Rate |
| CI/CD | Continuous Integration/Deployment |
| CORS | Cross-Origin Resource Sharing |
| DoD | Definition of Done |
| DORA | DevOps Research and Assessment |
| KPI | Key Performance Indicator |
| MTTR | Mean Time to Recovery |
| OWASP | Open Web Application Security Project |
| PCI-DSS | Payment Card Industry Data Security Standard |
| QA | Quality Assurance |
| SAST | Static Application Security Testing |
| SDD | Spec-Driven Development |
| SOX | Sarbanes-Oxley |
| SQL | Structured Query Language |
| TDD | Test-Driven Development |
| WIP | Work In Progress |

---

## Conceptos Relacionados (Pero Diferentes)

### Scrum vs. Savia Flow
- **Scrum:** Sprints fijos, story points, burndown charts
- **Savia Flow:** Flujo continuo, DORA metrics, outcome-driven

### User Stories vs. Specs
- **User Stories:** Narrativas ("As a user, I want..."), ambiguas
- **Specs:** Ejecutables, precisas, con success metrics

### Velocity vs. Cycle Time
- **Velocity:** Puntos/sprint, gameable, no predice bien con IA
- **Cycle Time:** Días a producción, factual, excelente con IA

### QA Manual vs. Quality Gates
- **QA Manual:** Humano testa después del build
- **Quality Gates:** Automatizadas en CI/CD, feedback inmediato

---

**Comienza con este glosario. Referencia frecuente ayuda a onboarding.**
