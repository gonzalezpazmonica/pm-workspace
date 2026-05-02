# Spec: SCM Frontmatter Coverage — Cerrar gaps de indexacion

**Task ID:**        SPEC-SCM-COVERAGE
**PBI padre:**      SE-084 — Skill catalog quality audit (Era 190)
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (auditoria SCM integrity)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     S 1h
**Estado:**         Pendiente
**Prioridad:**      ALTA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      8

---

## 1. Contexto y Objetivo

El SCM (Savia Capability Map) indexa recursos del workspace para routing
de agentes y busqueda de capacidades. La auditoria revelo que 2 comandos
de 534 no estan indexados porque carecen de frontmatter YAML:

- `court-review.md` — sin frontmatter
- `trace-optimize.md` — sin frontmatter

Ambos archivos existen en `.claude/commands/` y `.opencode/commands/`
pero son invisibles para el capability map. Si un agente o skill intenta
enrutar hacia ellos via SCM, fallara porque no aparecen en INDEX.scm.

**Objetivo:** Anadir frontmatter YAML con `name` y `description` a ambos
comandos para que el SCM los indexe correctamente. La cobertura pasara
de 532/534 a 534/534 (100%).

---

## 2. Requisitos Funcionales

- **REQ-01** `court-review.md` debe tener frontmatter con `name` y `description`.
- **REQ-02** `trace-optimize.md` debe tener frontmatter con `name` y `description`.
- **REQ-03** Tras la correccion, `generate-capability-map.py` debe producir
  1128 recursos (+2 commands respecto a los 1126 actuales).
- **REQ-04** La linea `> 532 commands` en INDEX.scm debe pasar a `> 534 commands`.
- **REQ-05** Ambos comandos deben aparecer en su categoria correspondiente
  dentro de `.scm/categories/`.

---

## 3. Frontmatter a Anadir

### court-review.md

```yaml
---
name: Court Review
description: Convene the Code Review Court to evaluate implementation quality across 6 judges
---
```

### trace-optimize.md

```yaml
---
name: Trace Optimize
description: Optimize trace spans and sampling rates across distributed services
---
```

---

## 4. Criterios de Aceptacion

- **AC-01** `court-review.md` tiene frontmatter valido con `name` y `description` no vacios.
- **AC-02** `trace-optimize.md` tiene frontmatter valido con `name` y `description` no vacios.
- **AC-03** `python3 scripts/generate-capability-map.py` reporta "534 commands".
- **AC-04** INDEX.scm contiene entradas para `[category] Court Review` y `[category] Trace Optimize`.
- **AC-05** SCM hash cambia deterministicamente (no hay timestamp en el output).

---

## 5. Ficheros a Modificar

| Fichero | Accion |
|---------|--------|
| `.claude/commands/court-review.md` | MODIFICAR: anadir frontmatter |
| `.claude/commands/trace-optimize.md` | MODIFICAR: anadir frontmatter |
| `.opencode/commands/court-review.md` | MODIFICAR: replicar mismo frontmatter |
| `.opencode/commands/trace-optimize.md` | MODIFICAR: replicar mismo frontmatter |
| `.scm/INDEX.scm` | REGENERAR: via generate-capability-map.py |
| `.scm/categories/` | REGENERAR: via generate-capability-map.py |

---

## 6. Test Scenarios

1. **SCM count**: ejecutar `generate-capability-map.py`. Verificar "534 commands" en output.
2. **INDEX grep**: `grep 'court-review' .scm/INDEX.scm` retorna 1 linea con `Court Review`.
3. **INDEX grep**: `grep 'trace-optimize' .scm/INDEX.scm` retorna 1 linea con `Trace Optimize`.
4. **Category assignment**: verificar que ambos comandos aparecen en el archivo de categoria correcto dentro de `.scm/categories/`.
