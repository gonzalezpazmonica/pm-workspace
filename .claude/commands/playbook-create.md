---
name: playbook-create
description: Crear playbooks evolutivos para tareas repetitivas con framework ACE
developer_type: all
agent: task
context_cost: high
---

# /playbook-create

> 🦉 Crea playbooks evolutivos que aprenden de cada ejecución.

Basado en el framework **ACE** (Agent, Curator, Executor) de arXiv 2510.04618.
Los playbooks capturan flujos repetitivos (releases, onboarding, audits, deploys)
y evolucionan con reflexiones acumuladas.

---

## Estructura de un Playbook

```yaml
# Trigger: cuándo ejecutar
trigger:
  event: "release.start"
  condition: "sprint_completed AND all_tests_pass"

# Pasos: qué ejecutar
steps:
  - name: "Validar artefactos"
    action: "check_build_artifacts"
    checkpoint: true
    
  - name: "Notificar stakeholders"
    action: "notify_team"
    depends_on: "Validar artefactos"

# Criterios de éxito
success_criteria:
  - "all_tests_pass: true"
  - "zero_critical_bugs: true"
  - "stakeholders_notified: true"

# Generaciones: evolución del playbook
generations:
  - id: "g1"
    date: "2026-03-02"
    reflections: []
    
  - id: "g2"
    date: "2026-03-09"
    reflections:
      - "Paso 1 fallaba 20% — añadir retry logic"
      - "Paso 2 tardaba 45min — paralelizar notificaciones"
```

---

## Comando

```
/playbook-create {nombre} [--from template|scratch] [--lang es|en]
```

**Parámetros:**
- `{nombre}` — Nombre del playbook (kebab-case): release, onboarding, audit, deploy
- `--from template` — Basarse en plantilla (release/onboarding/audit/deploy)
- `--from scratch` — Crear desde cero con wizard interactivo
- `--lang es|en` — Idioma (español por defecto)

---

## Proceso

### Paso 1 — Elegir fuente
- Mostrar plantillas disponibles si `--from template`
- Lanzar wizard si `--from scratch`

### Paso 2 — Definir trigger
- ¿Qué evento lanza el playbook?
- ¿Qué condiciones se deben cumplir?

### Paso 3 — Diseñar pasos
- PM describe los pasos (ejecutables por agentes)
- Savia sugiere checkpoints
- Validar dependencias

### Paso 4 — Criterios de éxito
- ¿Cuándo está completo el playbook?
- Métricas objetivas

### Paso 5 — Generar fichero
- Guardar en `projects/{project}/playbooks/{nombre}.yml`
- Crear generación inicial (g1, sin reflexiones)

---

## Output

```
📄 Playbook creado: projects/PROJ/playbooks/release.yml
✅ Trigger definido: release.start
✅ 5 pasos configurados
✅ 3 criterios de éxito

💡 Siguiente: ejecuta con /playbook-execute release
   Tras ejecución: /playbook-reflect release --session last
```

---

## Plantillas incluidas

- **release** — Deploy a producción con validación pre/post
- **onboarding** — Incorporación de nuevo miembro del equipo
- **audit** — Auditoría de seguridad trimestral
- **deploy** — Deployment a entornos no-producción
