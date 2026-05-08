# Spec: Zero Project Leakage — Multi-Project Context Isolation

**Task ID:**        SPEC-SE-093-ZERO-LEAK
**PBI padre:**      Era 196 — Production PM Operations
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (gap analysis)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion agent:** ~60 min
**Estado:**         Pendiente
**Prioridad:**      CRITICA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      20

---

## 1. Problema

La regla `docs/rules/domain/zero-project-leakage.md` declara el principio: "Savia nunca
mezcla datos de dos proyectos en la misma respuesta". Pero no hay enforcement.

Si Monica pregunta "cual es el estado del sprint del proyecto Foo?" y luego "y del
proyecto Bar?", Savia podria accidentalmente:
- Cruzar work items (PBI de Foo en informe de Bar)
- Referenciar specs de un proyecto en el contexto de otro
- Mencionar nombres de stakeholders entre proyectos

En un repo publico (pm-workspace es MIT, 39 stars), una fuga de datos entre proyectos
es una brecha de confidencialidad grave. No basta con "ser cuidadoso" — necesitamos
enforcement automatico.

## 2. Requisitos

- **REQ-01** `scripts/project-isolation-check.sh`: pre-response hook que verifica
  que la respuesta de Savia no contiene datos de proyectos distintos al activo.
  - Si el proyecto activo es "foo", la respuesta no puede contener paths
    `projects/bar/` ni nombres de stakeholders del proyecto "bar".
  - Se ejecuta como hook PostToolUse (non-blocking WARN).

- **REQ-02** `~/.savia-memory/projects/{name}/` — cada proyecto tiene su propio
  espacio de memoria aislado. El `memory-agent` carga SOLO la memoria del
  proyecto activo, no de otros.

- **REQ-03** Comando `/project-activate {name}` — cambia el contexto activo:
  - Carga `projects/{name}/CLAUDE.md`
  - Cambia `CLAUDE_PROJECT_DIR` a `projects/{name}/`
  - Limpia referencias al proyecto anterior del contexto activo

- **REQ-04** El SCM y el knowledge graph (SE-088) deben filtrarse por proyecto
  activo cuando corresponda. `/ua-analyze` sobre `projects/foo/` no mezcla
  nodos con `projects/bar/`.

- **REQ-05** Pre-commit hook verifica que los archivos commiteados no contienen
  referencias cruzadas entre proyectos (ej: spec en `projects/foo/specs/` que
  referencia `projects/bar/`).

---

## 3. Ficheros

| Fichero | Accion |
|---------|--------|
| `scripts/project-isolation-check.sh` | CREAR |
| `scripts/project-activate.sh` | CREAR |
| `.opencode/commands/project-activate.md` | CREAR |
| `docs/rules/domain/zero-project-leakage.md` | MODIFICAR (anadir enforcement) |

---

## 4. Criterios de Aceptacion

- **AC-01** Activar proyecto "foo" → pregunta sobre sprint → respuesta no menciona "bar".
- **AC-02** `project-isolation-check.sh` detecta y advierte fuga entre proyectos.
- **AC-03** Memoria de "foo" y "bar" son archivos separados, sin solapamiento.
- **AC-04** `/ua-analyze projects/foo` no indexa archivos de `projects/bar/`.
