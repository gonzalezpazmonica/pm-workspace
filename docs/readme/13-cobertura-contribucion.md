# Cobertura del workspace para gestión de proyectos

Esta sección responde a una pregunta clave para cualquier PM que evalúe adoptar esta herramienta: ¿qué cubre, qué no cubre y qué no puede cubrirse por definición?

## ✅ Contemplado y simplificado

Las siguientes responsabilidades clásicas del PM/Scrum Master quedan automatizadas o notablemente reducidas en carga:

| Must | Cobertura | Simplificación |
|------|-----------|----------------|
| Sprint Planning (capacity + selección de PBIs) | `/sprint-plan` | Alta — calcula capacity real, propone PBIs hasta llenarla y descompone en tasks con un solo comando |
| Descomposición de PBIs en tasks | `/pbi-decompose`, `/pbi-decompose-batch` | Alta — genera tabla de tasks con estimación, actividad y asignación. Elimina la reunión de refinamiento de tareas |
| Asignación de trabajo (balanceo de carga) | `/pbi-assign` + scoring algorithm | Alta — el algoritmo expertise×disponibilidad×balance elimina la intuición subjetiva y garantiza reparto equitativo |
| Seguimiento del burndown | `/sprint-status` | Alta — burndown automático en cualquier momento, con desviación respecto al ideal y proyección de cierre |
| Control de capacity del equipo | `/report-capacity`, `/team-workload` | Alta — detecta sobrecarga individual y días libres sin necesidad de hojas de cálculo manuales |
| Alertas de WIP y bloqueos | `/sprint-status` | Alta — alertas automáticas de items sin avance, personas al 100% y WIP sobre el límite |
| Preparación de la Daily | `/sprint-status` | Media — proporciona el estado exacto y sugiere los puntos a tratar, pero la Daily es humana |
| Informe de imputación de horas | `/report-hours` | Alta — Excel con 4 pestañas generado automáticamente desde Azure DevOps, sin edición manual |
| Informe ejecutivo multi-proyecto | `/report-executive` | Alta — PPT/Word con semáforos de estado, listo para enviar a dirección |
| Velocity y KPIs de equipo | `/kpi-dashboard` | Alta — velocity, cycle time, lead time, bug escape rate calculados con datos reales de AzDO |
| Sprint Review (preparación) | `/sprint-review` | Media — genera el resumen de items completados y velocity, pero la demo la hace el equipo |
| Sprint Retrospectiva (datos) | `/sprint-retro` | Media — proporciona los datos cuantitativos del sprint (qué fue bien, qué no), pero la dinámica es humana |
| Implementación de tasks repetibles (multi-lenguaje) | SDD + `/agent-run` | Muy alta — Handlers, Repositories, Validators, Unit Tests implementados sin intervención humana en 16 lenguajes |
| Gestión de infraestructura cloud | `/infra-plan`, `infrastructure-agent` | Alta — detección automática, creación al tier mínimo, escalado con aprobación humana |
| Configuración multi-entorno | `/env-setup`, `environment-config.md` | Alta — DEV/PRE/PRO configurables, secrets protegidos, pipelines por entorno |
| Control de calidad de specs | `/spec-review` | Alta — valida automáticamente que una spec tenga el nivel de detalle suficiente antes de implementar |
| Onboarding de nuevos miembros | `/team-onboarding`, `/team-evaluate` | Alta — guía personalizada de incorporación + cuestionario de 26 competencias con conformidad RGPD |

## 🔮 No contemplado actualmente — candidatos para el futuro

Áreas que serían naturalmente automatizables con Claude y que representan una evolución lógica del workspace:

**Gestión del backlog y refinement:** actualmente Claude descompone PBIs que ya existen, pero no asiste en la creación de nuevos PBIs desde cero (desde notas de cliente, emails, tickets de soporte). Un skill de `backlog-capture` que convierta inputs desestructurados en PBIs bien formados con criterios de aceptación sería un paso natural.

**Gestión de riesgos (risk log):** el workspace detecta alertas de WIP y burndown, pero no mantiene un registro estructurado de riesgos con probabilidad, impacto y plan de mitigación. Un skill de `risk-log` que actualice el registro en cada `/sprint-status` y escale riesgos críticos al PM sería valioso.

**Release notes automáticas:** al cierre del sprint, Claude tiene toda la información para generar las release notes desde los items completados y los commits. El comando `/changelog-update` cubre parcialmente este caso (genera CHANGELOG desde commits), pero un `/sprint-release-notes` específico que combine commits + work items sería el siguiente paso.

**Gestión de deuda técnica:** el workspace no rastrea ni prioriza la deuda técnica. Un skill que analice el backlog en busca de items marcados como "refactor" o "tech-debt" y los proponga para sprints de mantenimiento sería un añadido útil.

**Seguimiento de bugs en producción:** el bug escape rate se calcula, pero no hay un flujo automatizado para priorizar bugs entrantes, relacionarlos con el sprint en curso y proponer si impactan en el sprint goal actual.

**Estimación asistida de PBIs nuevos:** Claude podría estimar en Story Points un PBI nuevo basándose en el histórico de PBIs similares completados (análisis semántico de títulos y criterios de aceptación), reduciendo la dependencia del Planning Poker para items sencillos.

## 🚫 Fuera del alcance de la automatización — siempre humano

Estas responsabilidades no pueden ni deben delegarse a un agente por razones estructurales: requieren juicio contextual, responsabilidad formal, relación humana o decisión estratégica que no puede codificarse en una spec ni en un prompt.

**Decisiones de arquitectura** — Elegir entre microservicios y monolito, decidir si adoptar Event Sourcing, evaluar si cambiar de ORM o de cloud provider. Estas decisiones tienen implicaciones de años y requieren comprensión del negocio, el equipo y el contexto que ningún agente tiene. Claude puede informar y analizar opciones, pero no puede ni debe decidir.

**Code Review real** — El Code Review (E1 en el flujo SDD) es inviolablemente humano. Un agente puede hacer un pre-check de compilación y tests, pero la revisión de calidad, legibilidad, coherencia arquitectónica y detección de problemas sutiles de seguridad o rendimiento requiere un desarrollador senior con contexto del sistema.

**Gestión de personas** — Evaluaciones de rendimiento, conversaciones difíciles sobre productividad, decisiones de promoción, gestión de conflictos entre miembros del equipo, contratación y despido. Ningún dato de burndown ni de capacity reemplaza el juicio humano en estas situaciones.

**Negociación con el cliente o stakeholders** — El workspace genera informes y proporciona datos, pero la negociación de scope, la gestión de expectativas y la comunicación de malas noticias (un sprint que no se cierra, un bug crítico en producción) requieren presencia, empatía y autoridad de un PM real.

**Decisiones de seguridad y compliance** — Revisar que el código cumple con GDPR, evaluar el alcance de una brecha de seguridad, decidir si un módulo necesita penetration testing, obtener certificaciones de calidad. Estas decisiones conllevan responsabilidad legal que no puede recaer en un agente.

**Migraciones de base de datos en producción** — El workspace excluye explícitamente las migraciones del scope de los agentes. La reversibilidad, el rollback plan y la ventana de mantenimiento de una migración en producción deben estar en manos de un desarrollador que entienda el estado real de los datos.

**Aceptación y UAT (User Acceptance Testing)** — Los tests unitarios e de integración pueden automatizarse. La validación de que el software resuelve el problema real del usuario final, no. El UAT requiere usuarios reales, contexto de negocio y criterio que va más allá de un escenario Given/When/Then.

**Gestión de incidencias en producción (P0/P1)** — Cuando algo falla en producción, el triage, la comunicación de crisis, la decisión de hacer rollback y la coordinación entre equipos requieren un humano disponible, con autoridad y con contexto completo del sistema en producción.

**Definición de la visión y el roadmap del producto** — El workspace gestiona sprints, no estrategia de producto. Qué construir, por qué y en qué orden es una decisión de negocio que pertenece al Product Owner, al CEO o al cliente, no a un sistema de automatización.

---

## Cómo contribuir

Este proyecto está diseñado para crecer con las aportaciones de la comunidad. Si usas el workspace en un proyecto real y encuentras una mejora, un comando nuevo o una skill que falta, tu contribución es bienvenida.

### Qué tipos de contribución aceptamos

**Nuevos slash commands** (`.claude/commands/`) — el área de mayor impacto inmediato. Si has automatizado una conversación con Claude que resuelve un problema de PM no cubierto, empaquétala como comando y compártela. Ejemplos de alto interés: `risk-log`, `sprint-release-notes`, `backlog-capture`, `pr-status`.

**Nuevas skills** (`.claude/skills/`) — skills que amplíen el comportamiento de Claude en áreas nuevas (gestión de deuda técnica, integración con Jira, soporte para metodologías Kanban o SAFe, nuevos proveedores cloud).

**Ampliaciones del proyecto de test** (`projects/sala-reservas/`) — nuevos ficheros mock, nuevas specs de ejemplo, nuevas categorías en `test-workspace.sh`.

**Correcciones y mejoras de documentación** — aclaraciones en los SKILL.md, ejemplos adicionales en el README, traducciones.

**Bug fixes en scripts** (`scripts/`) — mejoras en `azdevops-queries.sh`, `capacity-calculator.py` o `report-generator.js`.

### Flujo de contribución

Este repositorio sigue **GitHub Flow**: ningún commit va directamente a `main`. Todo cambio pasa por rama de feature + Pull Request. Ver `.claude/rules/github-flow.md` para la referencia completa.

```
1. Fork del repositorio en GitHub
2. Crea una rama con nombre descriptivo (feature/, fix/, docs/, refactor/)
3. Desarrolla y documenta tu contribución
4. Ejecuta el test suite (debe pasar ≥ 93/96 en modo mock)
5. Abre un Pull Request siguiendo la plantilla
```

**Paso 1 — Fork y rama**

```bash
# Desde tu cuenta de GitHub, haz fork del repositorio
# Luego clona tu fork y crea tu rama de trabajo:

git clone https://github.com/TU-USUARIO/pm-workspace.git
cd pm-workspace
git checkout -b feature/sprint-release-notes
# o para fixes: git checkout -b fix/capacity-formula-edge-case
```

Convención de nombres de ramas:
- `feature/` — nueva funcionalidad (comando, skill, integración)
- `fix/` — corrección de un bug
- `docs/` — solo documentación
- `test/` — mejoras al test suite o datos mock
- `refactor/` — reorganización sin cambio de comportamiento

**Paso 2 — Desarrolla tu contribución**

Si añades un slash command nuevo, sigue la estructura de los existentes en `.claude/commands/`. Cada comando debe incluir:
- Descripción del propósito en las primeras líneas
- Pasos numerados del proceso que Claude debe seguir
- Manejo del caso de error más común
- Al menos un ejemplo de uso en el propio fichero

Si añades una skill nueva, incluye un `SKILL.md` con la descripción, cuándo se usa, parámetros de configuración y referencias a documentación relevante.

**Paso 3 — Verifica que los tests siguen pasando**

```bash
chmod +x scripts/test-workspace.sh
./scripts/test-workspace.sh --mock

# Resultado esperado: ≥ 93/96 PASSED
# Si tu contribución añade nuevos ficheros, añade también sus tests
# en la suite correspondiente de scripts/test-workspace.sh
```

**Paso 4 — Abre el Pull Request**

Usa esta plantilla para el cuerpo del PR:

```markdown
## ¿Qué añade o corrige este PR?
[Descripción en 2-3 frases]

## Tipo de contribución
- [ ] Nuevo slash command
- [ ] Nueva skill
- [ ] Fix de bug
- [ ] Mejora de documentación
- [ ] Ampliación del test suite
- [ ] Otro: ___

## Archivos modificados / creados
- `.claude/commands/nombre-comando.md` — [qué hace]
- `docs/` — [si aplica]

## Tests
- [ ] `./scripts/test-workspace.sh --mock` pasa ≥ 93/96
- [ ] He añadido tests para los nuevos ficheros (si aplica)

## Checklist
- [ ] El comando/skill sigue las convenciones de estilo de los existentes
- [ ] He probado la conversación con Claude manualmente al menos una vez
- [ ] No incluyo datos reales de proyectos, clientes ni PATs
```

### Criterios de aceptación de un PR

Un PR se acepta si cumple todos estos criterios y al menos uno de los mantenedores hace review:

El test suite sigue pasando en modo mock (≥ 93/96). El nuevo comando o skill tiene un nombre consistente con los existentes (kebab-case, namespace con `:` o `-`). No incluye credenciales, PATs, URLs internas ni datos reales de ningún proyecto. Si añade un fichero nuevo que debería existir en todos los proyectos (como `sdd-metrics.md`), también añade el test correspondiente en `test-workspace.sh`. La documentación inline en el fichero es suficiente para que otro PM entienda para qué sirve sin leer el código.

### Reportar un bug o proponer una feature

Abre un Issue en GitHub con uno de estos prefijos en el título:

```
[BUG]     /sprint-status no muestra alertas cuando WIP = 0
[FEATURE] Añadir soporte para metodología Kanban
[DOCS]    El ejemplo de SDD en el README no refleja el comportamiento actual
[QUESTION] ¿Cómo configurar el workspace para proyectos con múltiples repos?
```

Incluye siempre: versión de Claude Code usada (`claude --versión`), qué comando o skill está involucrado, qué comportamiento esperabas y qué obtienes, y si es reproducible con el proyecto de test `sala-reservas` en modo mock.

### Código de conducta

Las contribuciones deben ser respetuosas, técnicamente sólidas y orientadas a resolver problemas reales de gestión de proyectos. Se valoran especialmente las contribuciones que vienen acompañadas de un caso de uso real (anonimizado), ya que demuestran que la funcionalidad resuelve una necesidad genuina.

---

*PM-Workspace — PM automatizada con IA para equipos multi-lenguaje. Compatible con Azure DevOps, Jira y Savia Flow (Git-native).*
