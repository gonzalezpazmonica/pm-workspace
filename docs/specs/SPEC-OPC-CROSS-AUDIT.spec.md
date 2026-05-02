# Spec: OpenCode Cross-Audit Script — Verificar alineacion .opencode/ vs .claude/

**Task ID:**        SPEC-OPC-CROSS-AUDIT
**PBI padre:**      Era 189 — OpenCode Sovereignty (SE-077)
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (auditoria OpenCode alignment)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     S 3h
**Estado:**         Pendiente
**Prioridad:**      MEDIA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      15

---

## 1. Contexto y Objetivo

La auditoria de alineacion OpenCode revelo que aunque los contadores de
recursos (535 commands, 93 skills, 70 agents) coinciden entre `.claude/`
y `.opencode/`, no existe un mecanismo automatico que verifique esta
alineacion de forma continua. El SCM solo indexa desde `.claude/`,
dejando `.opencode/` sin cobertura de auditoria.

El unico script de conversion existente (`agents-opencode-convert.sh`)
solo cubre agentes y no verifica consistencia post-conversion.

**Objetivo:** Crear `scripts/opencode-cross-audit.sh` que compare
recursos entre `.claude/` y `.opencode/` (agents, commands, skills),
reporte diferencias, y pueda ejecutarse como gate en CI/pr-plan.

---

## 2. Requisitos Funcionales

- **REQ-01** `scripts/opencode-cross-audit.sh` compara:
  - `.claude/agents/` vs `.opencode/agents/` — archivos .md + subdirectorios
  - `.claude/commands/` vs `.opencode/commands/` — archivos .md (excluye `references/`)
  - `.claude/skills/` vs `.opencode/skills/` — directorios + SKILL.md contenido
- **REQ-02** Reporta formato tabla:
  ```
  === OpenCode Cross-Audit ===
  Agents:    70/70 OK, 0 missing, 0 drift
  Commands:  534/534 OK, 0 missing, 0 drift
  Skills:    92/92 OK, 0 missing, 0 drift
  Result: PASS
  ```
- **REQ-03** Exit code: 0 (PASS) o 1 (FAIL con diffs listados).
- **REQ-04** Comparacion de contenido: si un archivo existe en ambos
  lados, compara checksum (md5sum) para detectar drift de contenido.
- **REQ-05** Ignora directorios de infraestructura (`.opencode/scripts/`,
  `.opencode/hooks/`, `references/` dentro de commands/).
- **REQ-06** Modo `--fix`: para cada recurso con drift o ausente,
  copia desde `.claude/` → `.opencode/` (solo si `--fix` explicitamente).

---

## 3. Modo de Uso

```bash
bash scripts/opencode-cross-audit.sh          # Solo auditoria, exit code
bash scripts/opencode-cross-audit.sh --fix    # Auditoria + correccion automatica
bash scripts/opencode-cross-audit.sh --json   # Output en formato JSON
```

---

## 4. Criterios de Aceptacion

- **AC-01** Sobre workspace alineado (actual), el script reporta PASS con 0 drift.
- **AC-02** Tras modificar `court-review.md` solo en `.claude/commands/`, el script
  detecta drift en commands y reporta FAIL.
- **AC-03** Tras eliminar un agente de `.opencode/agents/`, el script detecta
  "missing" y reporta FAIL.
- **AC-04** `--fix` corrige drift copiando desde `.claude/` a `.opencode/`.
- **AC-05** `--fix` NO copia a `.claude/` desde `.opencode/` (`.claude/` es source of truth).
- **AC-06** Exit code 0 = PASS, 1 = FAIL, 2 = error de ejecucion.

---

## 5. Ficheros a Crear/Modificar

| Fichero | Accion |
|---------|--------|
| `scripts/opencode-cross-audit.sh` | CREAR |
| `scripts/agents-opencode-convert.sh` | MODIFICAR: delegar en cross-audit --fix para agentes |
| `scripts/pr-plan-gates.sh` | MODIFICAR: anadir gate G15 (opcional, WARN no-blocking) |

---

## 6. Integracion con pr-plan

Gate G15 (opcional, no bloqueante) en `pr-plan`:
- Nivel: WARN (no STOP)
- Condicion: ejecutar `opencode-cross-audit.sh` tras cambios en `.claude/agents/`,
  `.claude/commands/`, o `.claude/skills/`.
- Mensaje: "OpenCode drift detectado en {N} recursos. Ejecuta: bash scripts/opencode-cross-audit.sh --fix"

---

## 7. Test Scenarios

1. **Clean workspace**: ejecutar auditoria sobre workspace alineado. PASS.
2. **Agent drift**: modificar agente en `.opencode/agents/`. FAIL + diff listado.
3. **Command missing**: eliminar comando de `.opencode/commands/`. FAIL + "missing" listado.
4. **Skill drift**: modificar SKILL.md solo en `.opencode/skills/`. FAIL + diff listado.
5. **Fix mode**: `--fix` corrige todos los drift detectados. Tras fix, PASS.
6. **No reverse sync**: `--fix` jamas escribe a `.claude/`.
