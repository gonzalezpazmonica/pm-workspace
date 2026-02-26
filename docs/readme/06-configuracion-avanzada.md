# Configuración Avanzada por Proyecto

Cada proyecto tiene su `CLAUDE.md` con configuración propia que adapta el comportamiento de Claude a las particularidades del equipo y el contrato.

## Pesos de asignación (pbi-decomposition)

```yaml
# En projects/{proyecto}/CLAUDE.md
assignment_weights:
  expertise:    0.40   # Priorizar quien mejor conoce el módulo
  availability: 0.30   # Priorizar quien tiene más horas libres
  balance:      0.20   # Distribuir carga equitativamente
  growth:       0.10   # Dar oportunidades de aprendizaje
```

En proyectos de precio fijo, se puede ajustar: más peso en expertise y disponibilidad, `growth: 0.00` para no arriesgar el presupuesto.

## Configuración SDD

```yaml
# En projects/{proyecto}/CLAUDE.md
sdd_config:
  model_agent: "claude-opus-4-6"
  model_mid:   "claude-sonnet-4-6"
  model_fast:  "claude-haiku-4-5-20251001"
  token_budget_usd: 30          # Presupuesto mensual en tokens
  max_parallel_agents: 5

  # Sobreescribir la matrix global para este proyecto
  layer_overrides:
    - layer: "Authentication"
      force: "human"
      reason: "Módulo de seguridad — siempre revisión humana"
```

## Agregar un proyecto nuevo

1. Copia `projects/proyecto-alpha/` a `projects/tu-proyecto/`
2. Edita `projects/tu-proyecto/CLAUDE.md` con las constantes del nuevo proyecto
3. Añade el proyecto al `CLAUDE.md` raíz (sección `📋 Proyectos Activos`)
4. Clona el repo en `projects/tu-proyecto/source/`

---

## Ejemplo — Proyecto de precio fijo con SDD conservador

_Escenario: "ProyectoBeta" es un contrato cerrado. Quieres maximizar la velocidad del equipo senior y usar agentes solo en lo muy seguro, sin riesgo presupuestario._

```yaml
# projects/proyecto-beta/CLAUDE.md

PROJECT_TYPE = "precio-fijo"

assignment_weights:
  expertise:    0.55   # ← sube: siempre el mejor para cada task
  availability: 0.35   # ← sube: no sobrecargar en precio fijo
  balance:      0.10
  growth:       0.00   # ← baja a 0: no arriesgar horas de aprendizaje

sdd_config:
  model_agent: "claude-opus-4-6"
  model_mid:   "claude-sonnet-4-6"
  model_fast:  "claude-haiku-4-5-20251001"
  agentization_target: 0.40    # ← meta conservadora: solo 40% agentizado
  require_tech_lead_approval: true  # ← Carlos revisa CADA spec antes de lanzar agente
  cost_alert_per_spec_usd: 1.50     # ← alerta si una spec supera $1.50
  token_budget_usd: 15              # ← presupuesto mensual ajustado

  layer_overrides:
    - layer: "Domain"       force: "human"  reason: "precio fijo — 0 riesgo"
    - layer: "Integration"  force: "human"  reason: "APIs externas del cliente"
    - layer: "Migration"    force: "human"  reason: "cambios irreversibles en BBDD"
```

**Con esta configuración, Claude sabrá automáticamente:**
- Proponer solo las tasks más seguras al agente (validators, unit tests, DTOs)
- Pedir aprobación del Tech Lead antes de lanzar cualquier agente
- Avisar si el coste estimado de una spec supera $1.50
- Asignar siempre al miembro con más expertise en el módulo (expertise: 0.55)

---
