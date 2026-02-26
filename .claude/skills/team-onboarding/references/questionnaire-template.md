# Cuestionario de Evaluación de Expertise

## Instrucciones

Este cuestionario evalúa las competencias técnicas y transversales del programador para alimentar el algoritmo de asignación de tareas de pm-workspace y planificar mentoring.

**Formato:** autoevaluación validada por el Tech Lead.
- El programador se evalúa en cada competencia (nivel 1-5 + interés S/N).
- El Tech Lead revisa y ajusta si hay discrepancia > ±1 nivel.
- Ambos confirman el resultado final.

**Escala de niveles:**

| Nivel | Nombre | Descripción |
|-------|--------|-------------|
| 1 | **Aprendiz** | Conoce la teoría básica. Necesita supervisión constante. |
| 2 | **Practicante** | Trabaja con guía. Resuelve problemas conocidos siguiendo patrones. |
| 3 | **Competente** | Trabaja de forma autónoma. Consulta con un experto en casos complejos. |
| 4 | **Experto** | Resuelve problemas complejos, hace mentoring, propone mejoras. |
| 5 | **Referente** | Diseña soluciones originales. Persona de referencia del equipo en esta área. |

---

## Sección A — Competencias Técnicas .NET/C#

| # | Competencia | Evidencia verificable | Nivel (1-5) | Interés (S/N) |
|---|-------------|----------------------|:-----------:|:--------------:|
| A1 | **C# y OOP** — herencia, interfaces, genéricos, LINQ, async/await | Puede escribir un QueryHandler asíncrono con LINQ sin ayuda | | |
| A2 | **Clean Architecture** — capas Domain, Application, Infrastructure, API | Sabe en qué capa va cada clase y por qué | | |
| A3 | **CQRS y MediatR** — Commands, Queries, Handlers, Pipeline Behaviors | Puede crear un nuevo Command + Handler de cero | | |
| A4 | **Entity Framework Core** — DbContext, Fluent API, Migrations, Queries | Puede configurar una entidad con relaciones y escribir consultas eficientes | | |
| A5 | **FluentValidation** — Validators, reglas de negocio, mensajes custom | Puede crear un AbstractValidator completo para un DTO | | |
| A6 | **Unit Testing** — xUnit/NUnit, Moq/NSubstitute, patrón AAA | Puede escribir tests con mocks para un Handler sin ver ejemplos | | |
| A7 | **Integration Testing** — TestServer, TestContainers, fixtures | Puede montar un test que levante la API y haga requests reales | | |
| A8 | **API REST** — Controllers, routing, model binding, Swagger, versionado | Puede diseñar un endpoint RESTful con status codes correctos | | |
| A9 | **SQL y bases de datos** — T-SQL, índices, planes de ejecución, migraciones | Puede optimizar una query lenta analizando el plan de ejecución | | |
| A10 | **Seguridad** — autenticación JWT, autorización basada en roles/políticas, OWASP | Puede implementar un middleware de autorización | | |
| A11 | **SOLID y Design Patterns** — DI, Repository, Factory, Strategy | Sabe identificar violaciones SOLID en code review | | |
| A12 | **CI/CD y DevOps básico** — Azure DevOps Pipelines, Docker, YAML | Puede leer y modificar un pipeline YAML existente | | |

---

## Sección B — Competencias Transversales

| # | Competencia | Evidencia verificable | Nivel (1-5) | Interés (S/N) |
|---|-------------|----------------------|:-----------:|:--------------:|
| B1 | **Git avanzado** — branching, rebase, cherry-pick, resolución de conflictos | Puede resolver un merge conflict complejo sin perder código | | |
| B2 | **Code Review** — dar y recibir feedback constructivo | Da reviews que mejoran el código sin generar conflicto | | |
| B3 | **Documentación técnica** — XML docs, READMEs, ADRs | Documenta sus decisiones técnicas por escrito | | |
| B4 | **Comunicación con stakeholders** — explicar técnico a no-técnicos | Puede explicar un problema técnico al Product Owner | | |
| B5 | **Estimación de esfuerzo** — Story Points, descomposición de tareas | Sus estimaciones se desvían <30% del real | | |
| B6 | **Mentoring** — capacidad de enseñar a otros | Ha guiado a un junior en una tarea completa | | |
| B7 | **Trabajo con IA** — Claude Code, Copilot, prompting efectivo | Usa IA como acelerador sin perder comprensión del código | | |

---

## Sección C — Conocimiento del Dominio

> **Nota:** Esta sección se personaliza para cada proyecto. Listar los módulos
> o áreas de dominio del proyecto y evaluar el conocimiento del programador en cada uno.

| # | Área de dominio | Nivel (1-5) | Interés (S/N) |
|---|----------------|:-----------:|:--------------:|
| C1 | [Módulo 1 — descripción] | | |
| C2 | [Módulo 2 — descripción] | | |
| C3 | [Módulo 3 — descripción] | | |
| C4 | [Módulo 4 — descripción] | | |

---

## Resultado

**Evaluado:** _________________________ Fecha: ___________

**Tech Lead:** _________________________ Firma: ___________

**Observaciones del Tech Lead:**

(Anotar aquí cualquier ajuste realizado sobre la autoevaluación, con justificación)

---

**Próximo paso:** los resultados se procesan con el algoritmo de `references/expertise-mapping.md` y se registran en `equipo.md`.
