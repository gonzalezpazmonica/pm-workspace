# Spec: Documentation Health Auditor — Broken Links + Stale Refs

**Task ID:**        SPEC-SE-094-DOC-AUDIT
**PBI padre:**      SE-084 Slice 3 — Skill catalog quality audit
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (gap analysis)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion agent:** ~45 min
**Estado:**         Pendiente
**Prioridad:**      ALTA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      20

---

## 1. Problema

`skill-audit.sh` (SE-084 S1) audita la calidad de skills. Pero no hay equivalente
para documentacion. Con 85+ specs, 25+ reglas, 150+ docs, la deuda de documentacion
crece silenciosamente:

- Un spec referencia otro spec que fue archivado → enlace roto
- Una regla cita una feature que no esta implementada → referencia falsa
- Un README enlaza a un archivo que cambio de nombre → 404 en docs
- Secciones "TODO" o "TBD" acumuladas en specs → falsa sensacion de completitud
- Referencias a versiones antiguas de herramientas (ej: "Claude Code 2025" → ya es 2026)

## 2. Requisitos

- **REQ-01** `scripts/doc-health-audit.sh`: escanea todos los `.md` en `docs/`
  y `.opencode/skills/*/` verificando:
  - **Broken internal links**: `[text](./path.md)` donde el archivo no existe
  - **Broken section links**: `[text](./file.md#section)` donde la seccion no existe
  - **Stale spec refs**: `SPEC-NNN` que esta ARCHIVED o no existe
  - **TBD/TODO sections**: secciones marcadas como pendientes
  - **Orphan references**: specs referenciados en ROADMAP que no existen en `docs/specs/`

- **REQ-02** Salida en formato tabla con severidad:
  ```
  === Documentation Health Audit ===
  Broken links:  3 (HIGH)
  Stale refs:    12 (MEDIUM)
  TBD sections:  8 (LOW)
  Orphan refs:   2 (HIGH)
  Score: 72/100
  ```

- **REQ-03** CI Gate (WARN): ejecutar en PRs que tocan `docs/`. Si el score baja,
  advertir. Si hay broken links, FAIL.

- **REQ-04** El auditor NO modifica archivos. Solo reporta. Las correcciones las
  hace un agente o humano.

---

## 3. Ficheros

| Fichero | Accion |
|---------|--------|
| `scripts/doc-health-audit.sh` | CREAR |
| `scripts/pr-plan-gates.sh` | MODIFICAR — Gate G17 (WARN) |

---

## 4. Criterios de Aceptacion

- **AC-01** `doc-health-audit.sh` detecta al menos 1 broken link actual (si existe).
- **AC-02** Score > 80/100 tras correcciones (linea base inicial puede ser menor).
- **AC-03** CI no bloquea por doc health (WARN), pero muestra el score.
- **AC-04** No modifica archivos (read-only).
