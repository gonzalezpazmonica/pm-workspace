---
name: okr-align
description: Visualizar alineación proyecto→OKR→estrategia corporativa
developer_type: all
agent: task
context_cost: high
---

# /okr-align

> 🦉 Savia dibuja el mapa de alineación entre tus proyectos, OKRs y estrategia corporativa.

---

## Cargar perfil

Grupo: **Reporting** — cargar:

- `company/strategy.md` — OKRs definidos
- `company/structure.md` — departamentos y equipos
- `projects/{proyecto}/CLAUDE.md` — para cada proyecto

---

## Subcomandos

- `/okr-align` — mapa de alineación visual completo
- `/okr-align --gaps` — detectar proyectos huérfanos y OKRs sin soporte
- `/okr-align --project {name}` — alineación específica de un proyecto

---

## Flujo

### Paso 1 — Construir grafo de alineación

Nodos: Estrategia → Objetivos → Key Results → Proyectos → Teams

Aristas: Objetivo contribuye a Estrategia, KR parte de Objetivo, Proyecto entrega KR, Team ejecuta Proyecto.

### Paso 2 — Detectar proyectos huérfanos

Proyectos sin vinculación a ningún KR (sin contribución estratégica):

```
🔴 Proyectos huérfanos (3 detectados):
   - auth-service, documentation-site, legacy-admin-panel
  Preguntas: ¿son soporte técnico? ¿crear OKR de DevEx?
```

### Paso 3 — Detectar OKRs sin soporte

Key Results sin proyectos asignados o con solo 1 proyecto:

```
🟡 KR 1.3 "Satisfaction ≥ 9.0" — solo customer-support (debería tener 2+)
🔴 KR 2.1 "Velocity +50%" — sin proyectos asignados
```

### Paso 4 — Presentar mapa y métricas

Tree-view de alineación: Estrategia → Objetivos → KRs → Proyectos.

Métricas: proyectos total/alineados/huérfanos, OKRs con soporte, alignment score (0-10).

Recomendaciones: qué proyectos reforzar, qué OKRs crear, qué retirar.

### Paso 5 — Validar reglas de negocio

Para cada vínculo proyecto → KR:
- ¿Qué deliverables? ¿Cómo se mide impacto? ¿Timeline? ¿Owner?

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: okr_alignment_analysis
alignment_score: {0-10}
orphan_projects: {n}
unsupported_okrs: {n}
report_file: "output/YYYYMMDD-okr-alignment.md"
```

---

## Restricciones

- **NUNCA** remover proyectos automáticamente — solo señalar huérfanos
- **NUNCA** modificar OKRs — solo proponer
- Proyectos técnicos sin OKR (refactor, infra) son normales (mantención)
- Validación final = PM + team leads (no automática)
