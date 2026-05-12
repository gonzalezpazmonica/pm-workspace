---
name: portfolio-deps
description: Grafo de dependencias inter-proyecto — visualiza y alerta sobre cuellos de botella entre proyectos
developer_type: all
agent: task
context_cost: high
---

# /portfolio-deps

> 🦉 Savia mapea las dependencias entre tus proyectos para que nada se quede bloqueado sin que lo sepas.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, rol
- `preferences.md` — language, detail_level
- `projects.md` — todos los proyectos del portfolio
- `tone.md` — formality

---

## Subcomandos

- `/portfolio-deps` — grafo completo de dependencias inter-proyecto
- `/portfolio-deps --critical` — solo dependencias con riesgo de bloqueo
- `/portfolio-deps --project {nombre}` — dependencias de un proyecto específico

---

## Flujo

### Paso 1 — Escanear dependencias declaradas

Para cada proyecto en `projects/`:

1. Leer `CLAUDE.md` del proyecto — buscar referencias a otros proyectos
2. Leer backlog — PBIs con tags "depends-on", "blocked-by" o enlaces inter-proyecto
3. Leer pipelines — artefactos consumidos de otros repositorios
4. Leer NuGet/npm/Maven refs — paquetes internos publicados por otros proyectos

### Paso 2 — Construir grafo

```
📊 Dependency Graph — Portfolio

  [proyecto-A] ──depends──▶ [proyecto-B] (API v2.1)
       │                         │
       └──depends──▶ [proyecto-C] ◀──depends── [proyecto-D]
                      (shared-lib)

  Nodos: {N} proyectos
  Aristas: {N} dependencias
  Proyectos hub (≥3 dependientes): {lista}
  Proyectos isla (sin dependencias): {lista}
```

### Paso 3 — Análisis de riesgo

| Dependencia | Tipo | Estado | Riesgo |
|---|---|---|---|
| A → B (API) | Runtime | B en sprint retrasado | 🔴 Alto |
| A → C (lib) | Build-time | C estable | 🟢 Bajo |
| D → C (lib) | Build-time | C con breaking change planificado | 🟡 Medio |

Riesgo = f(tipo_dependencia, estado_proyecto_origen, cambios_planificados)

### Paso 4 — Alertas y recomendaciones

```
⚠️ Alertas de dependencia

  🔴 proyecto-B está retrasado 3 días → proyecto-A se verá afectado
     Recomendación: sincronizar con TL de proyecto-B, evaluar mock temporal

  🟡 proyecto-C planea breaking change en Sprint 8
     Afecta a: proyecto-A, proyecto-D
     Recomendación: coordinar migración antes del breaking change
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: portfolio_deps
projects_scanned: 5
dependencies: 8
critical_risks: 1
hub_projects: ["proyecto-C"]
isolated_projects: ["proyecto-E"]
```

---

## Restricciones

- **NUNCA** inventar dependencias — solo las detectadas en código/config/backlog
- **NUNCA** mostrar código fuente de otros proyectos sin contexto
- Si no hay acceso a un proyecto → marcar como "no escaneado"
- Tono constructivo: el objetivo es coordinación, no señalar culpables
