# Guía: Startup en Fase Temprana

> Escenario: equipo de 2–6 personas construyendo un MVP. Prioriza velocidad, iteración rápida y validación con usuarios reales. Sin presupuesto para herramientas enterprise.

---

## Tu startup

| Rol | Quién (a veces la misma persona) | Comandos principales |
|---|---|---|
| **Founder / CEO** | Visión, priorización, stakeholders | `/ceo-report`, `/value-stream-map`, `/okr-track` |
| **CTO / Lead Dev** | Arquitectura, implementación, tech debt | `/arch-detect`, `/debt-analyze`, `/spec-implement` |
| **Fullstack Dev** | Código, features, bugs | `/my-focus`, `/flow-task-move`, `/pr-review` |
| **Product / Design** | UX, discovery, métricas | `/pbi-jtbd`, `/feature-impact`, `/stakeholder-report` |

---

## ¿Por qué Savia para una startup?

- **Coste cero**: Git + Claude Code. Sin licencias de Jira, Asana ni Linear.
- **Velocidad**: de idea a spec ejecutable en minutos con SDD.
- **Un solo repo para todo**: código, gestión, docs, comunicación.
- **Escala contigo**: empiezas con Savia Flow standalone, añades Azure DevOps/Jira cuando crezcas.
- **Métricas desde el día 1**: velocity, DORA, burndown — no esperes a tener 50 personas para medir.

---

## Setup en 10 minutos

### 1. Clonar pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

### 2. Presentarte a Savia

> "Hola Savia, soy el CTO de una startup. Somos 3 personas construyendo un SaaS de gestión de inventario. Usamos React + Node.js."

Savia te guía por `/profile-setup` y adapta sus sugerencias a tu stack y contexto.

### 3. Definir OKRs (opcional pero recomendado)

> "Savia, define los OKRs del trimestre"

```
/okr-define
```

Ejemplo:
- **O1**: Lanzar MVP funcional
  - KR1: 5 features core implementadas
  - KR2: 10 usuarios beta activos
  - KR3: <3s tiempo de carga

---

## El ciclo lean con Savia

### Discovery → PBI

> "Savia, analiza esta idea de feature con Jobs-to-Be-Done"

```
/pbi-jtbd "Gestión de alertas de stock bajo"
```

Savia genera: job statement, outcome expectations, y criterios de valor. Esto se convierte en un PBI priorizado.

### PBI → Spec → Implementación

```
/savia-pbi create "Alerta de stock bajo por email" --project mvp
/pbi-decompose {id}                  → Tasks con estimación
/spec-generate {task-id}             → Spec SDD ejecutable
/spec-implement {spec}               → Implementar (tú o agente Claude)
```

**El poder del SDD para una startup**: puedes delegar la implementación a un agente Claude mientras tú hablas con clientes. La spec garantiza que el agente haga exactamente lo que necesitas.

### Validar → Iterar

```
/feature-impact --roi                → ¿Esta feature mueve la aguja?
/okr-track                           → ¿Estamos avanzando hacia los OKRs?
```

---

## Día a día (todos hacen de todo)

### Mañana — 15 min

> "Savia, ¿qué es lo más importante hoy?"

```
/my-focus                            → Tu item más prioritario
/savia-board mvp                     → Board del proyecto
```

### Durante el día

```
/flow-task-move TASK-005 in-progress → Empiezo
/spec-implement {spec}               → Implemento o delego a agente
/pr-review                           → Review rápido
/flow-task-move TASK-005 done        → Hecho
```

### Viernes — Demo + métricas

> "Savia, genera métricas de la semana para la retro"

```
/sprint-review                       → Qué se entregó
/velocity-trend                      → ¿Vamos más rápido o más lento?
/debt-analyze                        → ¿Estamos acumulando deuda?
```

---

## Cuándo escalar

| Señal | Acción |
|---|---|
| >6 personas en el equipo | Añadir `/jira-connect` o Azure DevOps |
| Inversor pide métricas formales | `/ceo-report --format pptx` |
| Necesitas CI/CD serio | Integrar GitHub Actions + PR Guardian |
| Equipo remoto crece | Activar Company Savia para comunicación cifrada |

---

## Tips para startups

- No sobre-proceses. Savia se adapta a tu ritmo — si un sprint de 1 semana funciona, úsalo
- Usa `/spec-implement` con agentes Claude para multiplicar tu capacidad de desarrollo
- `/debt-analyze` cada 2 semanas evita sorpresas cuando necesites escalar
- Mide desde el día 1 aunque seas 2 personas — los datos acumulados tienen un valor enorme
- `/pbi-jtbd` antes de cada feature nueva — evita construir cosas que nadie necesita
