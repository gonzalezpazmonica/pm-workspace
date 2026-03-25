# Guía: Consultora de Software con Azure DevOps

> Escenario: equipo de 4–15 personas en una consultora que entrega proyectos a clientes usando Azure DevOps como herramienta de gestión y CI/CD.

---

## Tu equipo

| Rol | Quién es | Qué necesita de Savia |
|---|---|---|
| **PM / Scrum Master** | Coordina sprints, reporta al cliente | `/sprint-status`, `/report-executive`, `/ceo-report` |
| **Tech Lead** | Decisiones técnicas, code review | `/arch-health`, `/tech-radar`, `/pr-review` |
| **Developers** (3–8) | Implementación | `/my-sprint`, `/my-focus`, `/spec-implement` |
| **QA** | Testing, validación | `/qa-dashboard`, `/testplan-generate` |
| **Product Owner** | Backlog, priorización | `/value-stream-map`, `/feature-impact` |

---

## Setup inicial (día 1)

### 1. Instalar pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
```

### 2. Configurar Azure DevOps

Edita `CLAUDE.md` con tu organización:

```
AZURE_DEVOPS_ORG_URL = "https://dev.azure.com/tu-organización"
AZURE_DEVOPS_PAT_FILE = "$HOME/.azure/devops-pat"
```

Guarda tu PAT en el fichero indicado (nunca en el repo).

### 3. Primer contacto con Savia

Abre Claude Code y di:

> "Hola, soy Ana, PM en una consultora de software. Usamos Azure DevOps."

Savia se presentará y te guiará por `/profile-setup` para conocerte: tu nombre, rol, proyectos, horarios, preferencias de comunicación.

### 4. Conectar tu proyecto

> "Conecta el proyecto sala-reservas de Azure DevOps"

Savia ejecutará `/devops-validate` para auditar la configuración: process template, estados, campos, iteraciones. Si hay incompatibilidades, te propondrá un plan de remediación.

### 5. Onboarding del equipo

Por cada miembro:

> "Incorpora a carlos como developer senior en el proyecto sala-reservas"

Savia usará `/team-onboarding` para crear su perfil, evaluar competencias y asignar permisos.

---

## Día a día del PM

### Lunes — Planning

```
/daily-routine                     → Savia te propone la rutina del día
/sprint-status                     → Estado actual del sprint
/backlog-groom --top 10            → Revisar los 10 primeros items
/pbi-decompose {id}                → Descomponer PBI en tasks
/sprint-plan                       → Planificar el sprint
```

**Conversación típica:**

> "Savia, ¿cómo va el sprint actual?"

Savia responde con burndown, capacity restante, items en riesgo y sugerencias.

> "Descompón el PBI 1234 en tasks y asígnalas al equipo"

Savia analiza el PBI, genera tasks con estimación en horas, y propone asignaciones usando el scoring (expertise × disponibilidad × balance × crecimiento).

### Daily standup (09:15)

> "Savia, prepara el standup de hoy"

Savia recopila: items movidos ayer, bloqueos detectados, items en riesgo por SLA. Genera un resumen ejecutivo para compartir en la daily.

### Viernes — Review + Retro

```
/sprint-review                     → Resumen de lo entregado
/sprint-retro                      → Retrospectiva estructurada
/report-executive                  → Informe para el cliente
/kpi-dashboard                     → Métricas del sprint
```

---

## Día a día del Developer

### Al empezar el día

> "Savia, ¿en qué debería trabajar hoy?"

Savia ejecuta `/my-focus` y te muestra tu item más prioritario con todo el contexto cargado.

### Implementar una spec SDD

```
/spec-generate {task-id}           → Genera spec desde la task
/spec-design {spec}                → Diseña la solución
/spec-implement {spec}             → Implementa (humano o agente)
/spec-review {file}                → Code review
/spec-verify {spec}                → Verificación final
```

**Conversación típica:**

> "Savia, genera la spec para la task 5678"

Savia crea una spec ejecutable con: contexto, requisitos, criterios de aceptación, tests esperados, y ficheros a modificar. Si eres developer humano, la usas como guía. Si delegas a un agente Claude, lo ejecuta automáticamente.

### PRs y code review

> "Savia, revisa el PR #42"

Savia ejecuta `/pr-review` analizando: convenciones del proyecto, tests, security, performance, y genera comentarios constructivos.

---

## Día a día del Tech Lead

```
/arch-health --drift               → Detectar drift arquitectónico
/tech-radar                        → Estado del stack tecnológico
/team-skills-matrix --bus-factor   → Riesgos de conocimiento
/incident-postmortem               → Postmortem blameless
/debt-analyze                      → Hotspots de deuda técnica
```

**Conversación típica:**

> "Savia, ¿hay drift en la arquitectura del proyecto?"

Savia analiza el código contra los patterns detectados (Clean, DDD, CQRS...) y reporta desviaciones con sugerencias priorizadas.

---

## Flujo completo: de PBI a producción

1. **PO crea PBI** en Azure DevOps → Savia lo detecta con `/backlog-capture`
2. **PM descompone** → `/pbi-decompose` genera tasks con horas
3. **PM asigna** → `/pbi-assign` con scoring inteligente
4. **Dev genera spec** → `/spec-generate` crea la spec SDD
5. **Architect revisa** → `/spec-design` valida la solución
6. **Security review** → `/security-review` analiza OWASP
7. **Dev implementa** → `/spec-implement` (humano o agente)
8. **QA valida** → `/testplan-generate` + `/qa-regression-plan`
9. **PR + merge** → `/pr-review` + PR Guardian (CI automático)
10. **Release** → `/sprint-release-notes` genera notas

---

## Informes para el cliente

```
/report-executive                  → Informe semanal
/ceo-report --format pptx          → Presentación para dirección
/kpi-dora                          → Métricas DORA
/velocity-trend                    → Tendencia de velocidad
```

> "Savia, genera el informe semanal para el cliente en PowerPoint"

Savia crea un `.pptx` con: resumen del sprint, burndown, items completados, riesgos, y próximos pasos. Todo basado en datos reales de Azure DevOps.

---

## Tips específicos para Azure DevOps

- Savia valida automáticamente que tu proyecto cumple con el "Agile ideal" al conectarlo
- Los hooks de CI (`pr-guardian.yml`) se integran con Azure Pipelines
- `/pipeline-status` y `/pipeline-run` operan directamente contra Azure Pipelines
- Las connection strings y secrets nunca van al repo — usa `config.local/`
- Savia detecta si tu process template es Agile, Scrum o CMMI y se adapta
