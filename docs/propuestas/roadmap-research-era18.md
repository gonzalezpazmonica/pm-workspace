# Investigación Roadmap — Propuestas Era 18+

> Fecha: 2026-03-02
> Fuentes: 15 enlaces analizados (patrones AI, AEPD, skills.sh, Claude ecosystem, component gallery)
> Objetivo: Priorizar mejoras para pm-workspace basadas en tendencias externas

---

## Resumen Ejecutivo

La investigación revela tres ejes estratégicos principales: (1) madurar la infraestructura de calidad que ya tiene pm-workspace aplicando patrones probados, (2) posicionar pm-workspace en el ecosistema emergente de skills/plugins para agentes AI, y (3) reforzar la compliance regulatoria europea (AEPD) que es diferencial frente a herramientas anglosajonas.

---

## Hallazgos por Fuente

### 1. AI Coding Patterns — Buenas Prácticas Proyectos Mantenibles
**Fuente**: aicodingpatterns.com
**Relevancia**: ALTA — describe exactamente lo que pm-workspace ya hace con hooks

**Hallazgos clave**:
- Taxonomía de 3 tipos de hooks: Command (1-3s), Prompt (2-5s), Agent (30-120s)
- pm-workspace ya implementa Command hooks; falta explorar Prompt hooks (LLM para decisiones semánticas sin inspección de código) y Agent hooks (subagentes con acceso a ficheros para tests/seguridad)
- Principio de "calibración gradual": empezar permisivo con warnings, endurecer solo tras confirmar cero falsos positivos
- Anti-patrón: hooks PreToolUse excesivamente agresivos crean loops donde Claude reintenta variaciones

**Acciones propuestas**:
- Evaluar hooks tipo Prompt para validaciones semánticas (ej: "¿este commit message describe realmente lo que cambió?")
- Auditar hooks actuales para detectar posibles loops de reintento
- Documentar el coste en tokens de cada hook vs. el valor que aporta

### 2. Component Gallery
**Fuente**: component.gallery
**Relevancia**: MEDIA — inspiración para catálogo visual de commands/skills

**Hallazgos clave**:
- 60 componentes documentados de 95 design systems con 2676 ejemplos
- Modelo de organización: componente → variantes → ejemplos de implementación

**Acciones propuestas**:
- Crear un "Savia Gallery" — catálogo visual/interactivo de los 280+ comandos organizado por rol y vertical, similar a cómo component.gallery organiza UI components
- Mejorar la documentación de cada comando con ejemplos de input/output reales

### 3. Enrique Dans — Si la IA aprueba el examen, ¿qué estamos evaluando?
**Fuente**: Medium
**Relevancia**: MEDIA-BAJA — reflexión sobre competencias vs. conocimiento en era AI

**Hallazgos clave**:
- Las competencias evaluables cambian cuando la IA puede ejecutar las tareas técnicas
- El valor se desplaza a: pensamiento crítico, formulación de problemas, evaluación de outputs

**Acciones propuestas**:
- Reforzar el módulo de AI Adoption (`/adoption-assess`) con framework de competencias AI-era
- Vincular con role-evolution-ai.md para que las evaluaciones de competencias del equipo reflejen habilidades de "working with AI" no solo técnicas puras

### 4. AEPD — Orientaciones sobre IA Agéntica
**Fuente**: aepd.es
**Relevancia**: MUY ALTA — regulación española/europea directamente aplicable

**Hallazgos clave**:
- AEPD distingue IA agéntica (autónoma, con objetivos) de IA conversacional simple
- Foco en: protección de datos personales cuando agentes operan autónomamente
- Framework: descripción tecnológica → análisis de cumplimiento → evaluación de vulnerabilidades → medidas protectoras
- Privacy-by-design obligatorio antes del despliegue

**Acciones propuestas**:
- **PRIORITARIO**: Crear vertical `/aepd-compliance` con checks específicos para IA agéntica española
- Extender `/governance-audit` para incluir el framework AEPD (tecnología → cumplimiento → vulnerabilidades → medidas)
- Añadir a `/regulatory-compliance` los criterios específicos AEPD para agentes autónomos
- Documentar cómo pm-workspace/Savia cumple con las orientaciones AEPD (Savia es un agente autónomo que opera sobre datos de proyectos)
- Esto es diferencial: ninguna herramienta anglosajonas cubre regulación AEPD específica

### 5. Skills.sh — Marketplace de Skills para Agentes AI
**Fuente**: skills.sh
**Relevancia**: ALTA — canal de distribución para pm-workspace

**Hallazgos clave**:
- Marketplace agnóstico: Claude Code, Copilot, Cursor, Gemini
- Instalación con `npx skillsadd <owner/repo>`
- Leaderboard por instalaciones (82k+ totales)
- Skills rankeados por trending/instalaciones

**Acciones propuestas**:
- **PRIORITARIO**: Publicar skills de pm-workspace en skills.sh como paquetes individuales (sprint-management, capacity-planning, pbi-decomposition, etc.)
- Adaptar el formato de skills actuales al estándar de skills.sh
- Esto da visibilidad y tracción a pm-workspace fuera del ecosistema propio
- Evaluar el modelo para crear un marketplace propio de skills verticales (banking, healthcare, etc.)

### 6. Apify — State of Web Scraping 2026
**Fuente**: apify.com (PDF no legible completamente)
**Relevancia**: BAJA — web scraping no es core de pm-workspace

**Acciones propuestas**:
- Monitorizar por si emergen patrones útiles para data gathering en comandos de observabilidad

### 7. NotebookLM Guide
**Fuente**: mirenagk.kit.com
**Relevancia**: BAJA — guía de producto competidor (Google NotebookLM)

**Hallazgos clave**:
- NotebookLM gestiona fuentes para prevenir alucinaciones
- Genera contenido multimedia desde la interfaz de estudio

**Acciones propuestas**:
- Evaluar el concepto de "source management para prevenir alucinaciones" como feature para pm-workspace (vincular cada output de Savia con las fuentes que consultó)

### 8-15. Ecosistema Claude (Projects, Excel, Chrome, Cowork, Connectors, Opus 4.5)

**Hallazgos consolidados del ecosistema Claude**:

| Feature | Descripción | Relevancia para pm-workspace |
|---|---|---|
| **Claude Projects** | Conversaciones organizadas por proyecto con contexto persistente | pm-workspace ya lo resuelve con CLAUDE.md por proyecto — validar si Projects ofrece algo adicional |
| **Claude in Excel** | AI dentro de Excel: entiende workbooks completos, formulas, multi-tab | **ALTA** — `/capacity-planning` y `/time-tracking-report` podrían generar Excel interactivos con Claude |
| **Claude + Excel Revenue** | Validación de modelos financieros: detección de errores, escenarios, fórmulas dinámicas | Aplicable a `/ceo-report` y modelos de estimación de proyectos |
| **Claude + Excel HR Headcount** | Planificación de headcount: mapeo de datos entre tabs, detección de errores, análisis de escenarios | Directamente aplicable a `/capacity-planning` y `/capacity-forecast` |
| **Claude in Chrome** | Agente de navegación: acciones en web, multi-tab, shortcuts programables | Complemento natural para Savia: extraer datos de Azure DevOps portal, Jira web, etc. |
| **Claude Cowork** | Desktop automation: acceso a ficheros locales, sub-agentes paralelos, tareas recurrentes | **MUY RELEVANTE** — Savia YA funciona así con Claude Code. Evaluar si Cowork ofrece funcionalidades que Claude Code no tiene |
| **Claude Connectors** | Integraciones con apps externas (Slack, Asana, etc.) | Alternativa/complemento a MCP servers. Evaluar si simplifica la arquitectura de conexiones |
| **Claude Opus 4.5** | Modelo más potente | Ya configurado como CLAUDE_MODEL_AGENT para agentes estratégicos |

**Acciones propuestas del ecosistema Claude**:
- Crear guía de integración "pm-workspace + Claude Excel" para reportes financieros interactivos
- Evaluar Claude Connectors como alternativa más estable a MCP servers (arranque bajo demanda ya implementado en v0.83.0)
- Documentar la relación pm-workspace ↔ Claude Cowork (complementarios, no competidores)

---

## Propuesta de Priorización — Era 18

### Prioridad 1 (ALTA) — Compliance AEPD + Distribución

| # | Propuesta | Versión | Esfuerzo |
|---|---|---|---|
| 1 | `/aepd-compliance` — Vertical de compliance para IA agéntica española (framework AEPD) | v0.84.0 | Medio |
| 2 | Publicar skills en skills.sh — adaptar formato, publicar 5 skills core | v0.85.0 | Bajo |
| 3 | Extender `/governance-audit` con criterios AEPD (tecnología → cumplimiento → vulnerabilidades → medidas) | v0.84.0 | Bajo |

**Justificación**: La regulación AEPD sobre IA agéntica es nueva (2026) y pm-workspace puede ser la primera herramienta que la implemente. skills.sh da distribución inmediata con esfuerzo mínimo.

### Prioridad 2 (MEDIA-ALTA) — Hooks Inteligentes + Excel Integration

| # | Propuesta | Versión | Esfuerzo |
|---|---|---|---|
| 4 | Prompt hooks — validaciones semánticas via LLM (commit messages, PR descriptions, spec coherence) | v0.86.0 | Medio |
| 5 | Agent hooks — subagentes de verificación pre-merge (tests, seguridad, dependencias) | v0.86.0 | Alto |
| 6 | Excel reporting — templates interactivos para capacity-planning y ceo-report | v0.87.0 | Medio |

**Justificación**: Los patrones de aicodingpatterns.com validan la dirección de pm-workspace y sugieren el siguiente nivel (Prompt + Agent hooks). Excel integration amplía la audiencia a perfiles no-técnicos.

### Prioridad 3 (MEDIA) — Catálogo + Source Tracking

| # | Propuesta | Versión | Esfuerzo |
|---|---|---|---|
| 7 | Savia Gallery — catálogo visual/interactivo de comandos por rol y vertical | v0.88.0 | Medio |
| 8 | Source tracking — cada output de Savia incluye las fuentes consultadas (reglas, skills, docs) | v0.88.0 | Bajo |
| 9 | AI competency framework en `/adoption-assess` — habilidades para "working with AI" | v0.89.0 | Bajo |

### Prioridad 4 (BAJA) — Evaluación Estratégica

| # | Propuesta | Notas |
|---|---|---|
| 10 | Evaluar Claude Connectors vs MCP servers | ¿Simplifican la arquitectura? ¿Son más estables? |
| 11 | Documentar relación pm-workspace ↔ Claude Cowork | Complementarios: Cowork para usuarios finales, pm-workspace para equipos de desarrollo |
| 12 | Evaluar Claude in Chrome como canal de extracción de datos para Savia | Útil para portales web sin API (Azure DevOps portal, Jira web) |

---

## Fuentes

- [AI Coding Patterns — Buenas prácticas](https://aicodingpatterns.com/patterns/buenas-practicas-proyectos-mantenibles/)
- [Component Gallery](https://component.gallery/)
- [AEPD — Orientaciones IA Agéntica](https://www.aepd.es/prensa-y-comunicacion/notas-de-prensa/la-agencia-publica-unas-orientaciones-sobre-inteligencia)
- [Skills.sh — Marketplace de Skills](https://skills.sh/)
- [Claude in Excel](https://claude.com/resources/tutorials/getting-started-with-claude-in-excel)
- [Claude + Excel Revenue Validation](https://claude.com/resources/tutorials/how-to-use-claude-in-excel-for-accounting-revenue-model-validation)
- [Claude + Excel HR Headcount](https://claude.com/resources/tutorials/how-to-use-claude-in-excel-for-hr-headcount-planning)
- [Claude in Chrome](https://claude.com/resources/tutorials/simplify-your-browsing-experience-with-claude-for-chrome)
- [Claude Cowork](https://claude.com/resources/tutorials/claude-cowork-a-research-preview)
- [Claude Connectors](https://claude.com/resources/tutorials/getting-started-with-connectors)
- [Claude Projects](https://claude.com/resources/tutorials/intro-to-projects)
- [NotebookLM Guide](https://mirenagk.kit.com/notebook)
- [Enrique Dans — If AI can pass the assignment](https://medium.com/enrique-dans/if-ai-can-pass-the-assignment-what-are-we-really-testing-0da7dc7aeacd)
